library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

import '../core/diag_log.dart';
import 'capability.dart';
import 'engine_loader.dart';
import '../library/downloaded_tracks.dart';
import '../library/library_repository.dart';
import '../library/storage_permission.dart';

class DownloadJob {
  DownloadJob({
    required this.videoId,
    required this.title,
    this.channel = '',
    this.thumbnailUrl,
    this.duration,
    this.playlistName,
  });

  final String videoId;
  final String title;
  final String channel;
  final String? thumbnailUrl;
  final Duration? duration;

  final String? playlistName;

  int bytes = 0;

  double? fraction;

  String get progressText => fraction != null
      ? '${(fraction! * 100).round()}%'
      : (bytes > 0 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '…');
}

/// Thrown when the library folder exists but cannot be written to, which on
/// Android means the all-files grant is missing rather than the disk being full.
/// Why a download could not start. The service says which, the UI says it in the
/// reader's language; a sentence built here could only ever be English.
enum DownloadBlockKind { needsAllFiles, cannotWrite }

class DownloadBlocked implements Exception {
  const DownloadBlocked(this.kind);

  final DownloadBlockKind kind;

  @override
  String toString() => 'DownloadBlocked(${kind.name})';
}

/// A failed download, in the same spirit: a kind for the cases the UI can explain,
/// a detail string for the ones it can only report.
class DownloadIssue {
  const DownloadIssue.blocked(this.kind) : detail = null;
  const DownloadIssue.failed(this.detail) : kind = null;

  final DownloadBlockKind? kind;
  final String? detail;
}

/// Both download routes — the queue and the playlist importer — must clear this
/// before handing a folder to yt-dlp. Reading the library needs only the media
/// grant; writing into it needs all-files access, and a missing folder fails the
/// same way, so both are checked here instead of surfacing as a Python EPERM.
Future<void> ensureDownloadReady(Directory dir, {DiagLog? log}) async {
  final access = Platform.isAndroid
      ? await StoragePermission.status()
      : StorageAccess.granted;
  log?.add('DL storage=$access');
  if (access != StorageAccess.granted) {
    throw const DownloadBlocked(DownloadBlockKind.needsAllFiles);
  }

  try {
    await dir.create(recursive: true);
    final probe = File('${dir.path}${Platform.pathSeparator}.sonarar-write');
    await probe.writeAsString('', flush: true);
    await probe.delete();
  } on FileSystemException {
    throw const DownloadBlocked(DownloadBlockKind.cannotWrite);
  }
}

class DownloadManager extends ChangeNotifier {
  /// True when a download can run *now*: the engine is either compiled in or has
  /// been fetched. A lite build before its first install answers false.
  ///
  /// Overridable so a test can exercise both builds; production takes the
  /// compile-time constant.
  bool get canDownload => _downloadsAvailable || _engineReady;

  /// A lite build that can fetch its engine: downloads are late, not absent.
  bool get needsEngine =>
      !_downloadsAvailable && !_engineReady && engineFetchable;

  /// A build that can never download, because it can neither run nor fetch the
  /// engine.
  bool get downloadsCompiledOut => !_downloadsAvailable && !engineFetchable;

  /// What to tell someone who asked anyway — a stale bookmark, a deep link, an
  /// imported playlist that came with a video id.
  static const String notInThisBuild = 'Downloads are not part of this build.';

  /// A lite build can download, but only after the engine has been fetched.
  static const String engineNeeded = 'Downloads need a one-time 14 MB engine.';

  DownloadManager({
    required this.repo,
    required this.downloadDirOf,
    required this.manifestOf,
    this.onFiled,
    this.log,
    bool? downloadsAvailable,
  }) : _downloadsAvailable = downloadsAvailable ?? kDownloadsCompiledIn,
       // A build that was told it has no engine must not claim one, whatever the
       // compile-time default says - otherwise the gate opens for a build that
       // cannot possibly download.
       _engineReady = downloadsAvailable ?? kDownloadsCompiledIn;

  final bool _downloadsAvailable;

  /// Stage-by-stage trace. A native crash in yt-dlp leaves nothing behind but
  /// the last line written here, which is the whole point of it.
  final DiagLog? log;

  final LibraryRepository repo;

  final Directory? Function() downloadDirOf;

  final File? Function() manifestOf;

  final Future<void> Function()? onFiled;

  Directory? _dirCache;
  Directory get _dir {
    final d = _dirCache ??= downloadDirOf();
    if (d == null) throw StateError('the library root is not resolved yet');
    return d;
  }

  DownloadIssue? _lastIssue;

  /// Set when a download fails, and cleared once the UI has shown it.
  DownloadIssue? get lastIssue => _lastIssue;

  void clearError() {
    if (_lastIssue == null) return;
    _lastIssue = null;
    notifyListeners();
  }

  final List<DownloadJob> _queue = [];
  DownloadJob? _current;
  Timer? _poll;
  bool _running = false;

  DownloadJob? get current => _current;

  /// Whether the engine has to be fetched before a download can run.
  ///
  /// A full build ships it, so this is false there and stays false. A lite build
  /// starts needing it and stops once [installEngine] has succeeded, which is the
  /// only difference the rest of the app sees.

  /// A full build starts with the engine in place; a lite build does not.
  late bool _engineReady;

  /// A lite build fetches its engine on demand. Cleared only to model a build
  /// that genuinely cannot download at all.
  bool engineFetchable = true;

  bool _installing = false;

  bool get installingEngine => _installing;

  /// Why the last engine fetch failed, in the words of whatever failed.
  ///
  /// "It didn't work" was the whole of what a person could see before this, and the
  /// answer can be one of five things: no archive for the ABI, a checksum mismatch, a
  /// download that never finished, an install that could not unpack, or an engine that
  /// unpacked but would not start (which the plugin explains itself).
  String? _engineFailure;

  String? get engineFailure => _engineFailure;

  String? _installedReason;

  /// Fetch and install the engine once. Returns true when it is usable.
  ///
  /// The loader verifies the sha256 before anything is unzipped, so a truncated
  /// download fails here rather than half-installing over a working engine.
  Future<bool> installEngine({
    Future<List<int>> Function(Uri url)? download,
    void Function(double fraction)? onProgress,
  }) async {
    if (_engineReady || _installing) return _engineReady;
    _installing = true;
    notifyListeners();
    try {
      // Ask first: the archive is architecture-specific, and installing 14 MB of
      // the wrong interpreter fails at init with nothing useful to say.
      final abi = (await Ytdlp.capabilities()).abi;
      final source = engineSourceFor(abi);
      if (source == null) {
        _engineFailure = 'no archive for $abi';
        debugPrint('[Sonarar][DL] no engine archive for abi $abi');
        return false;
      }
      final loader = EngineLoader(
        source: source,
        readCache: () async => null,
        writeCache: (_) async {},
        download: download ?? _httpDownload,
        install: (path) async {
          final caps = await Ytdlp.installEngine(path);
          _engineReady = caps.engine;
          // The plugin knows why: a missing library, a payload that would not start.
          if (!caps.engine) _installedReason = caps.engineError;
          return caps.engine;
        },
        probe: () async => _engineReady,
        onProgress: onProgress,
      );
      final result = await loader.ensure();
      _engineReady =
          result == EngineInstall.ready || result == EngineInstall.alreadyThere;
      if (!_engineReady) {
        _engineFailure = switch (result) {
          EngineInstall.badArchive => 'the download did not match its checksum',
          EngineInstall.failed =>
            _installedReason ?? 'the archive would not install',
          _ => _engineFailure,
        };
        debugPrint('[Sonarar][DL] engine not ready: $_engineFailure');
      }
      return _engineReady;
    } on Exception catch (e) {
      // Offline, DNS failure, a 404 on the asset: all of it is "no engine yet",
      // and none of it may escape as an unhandled future from a button press.
      _engineFailure = e.toString();
      debugPrint('[Sonarar][DL] engine install failed: $e');
      return false;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  Future<List<int>> _httpDownload(Uri url) async {
    // A phone on a bad connection has to fail, not hang: the button must be able to
    // report something.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);
    try {
      final req = await client.getUrl(url);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw HttpException(
          'engine download failed: ${res.statusCode}',
          uri: url,
        );
      }

      // Fill once. `addAll` into a growing list copies everything collected so far on
      // every chunk — for a 14 MB archive that is gigabytes of copying and reads as a
      // hang before the checksum ever gets a say.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in res) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();

      // A short read is what the checksum catches later; catching it here says which
      // of the two it was.
      final declared = res.contentLength;
      if (declared > 0 && bytes.length != declared) {
        throw HttpException(
          'engine download was cut short: ${bytes.length} of $declared bytes',
          uri: url,
        );
      }
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  /// The single place that decides a job may run. Everything else assumes it.
  bool _refuseIfNoEngine() {
    if (canDownload) return false;
    _lastIssue = DownloadIssue.failed(
      needsEngine ? engineNeeded : notInThisBuild,
    );
    notifyListeners();
    return true;
  }

  List<DownloadJob> get queue => List.unmodifiable(_queue);

  int get pendingCount => _queue.length;

  bool get isBusy => _current != null;

  List<DownloadJob> get all => [if (_current != null) _current!, ..._queue];

  bool contains(String videoId) => jobFor(videoId) != null;

  /// Why this video's last download failed, if it did. A row can only say so
  /// if the reason is kept per video instead of in one global banner.
  final Map<String, DownloadIssue> _errors = {};

  DownloadIssue? errorFor(String videoId) => _errors[videoId];

  void clearErrorFor(String videoId) => _errors.remove(videoId);

  /// The job drawing progress for this video, if any. A row needs the job
  /// itself, not a copy of its numbers: copies go stale the moment the poller
  /// ticks, which is exactly how a download appears frozen.
  DownloadJob? jobFor(String videoId) {
    final current = _current;
    if (current != null && current.videoId == videoId) return current;
    for (final job in _queue) {
      if (job.videoId == videoId) return job;
    }
    return null;
  }

  String? coverPathForJob(DownloadJob job) {
    final dir = _dirCache ?? downloadDirOf();
    if (dir == null) return null;
    final f = File('${dir.path}${Platform.pathSeparator}${job.videoId}.jpg');
    return f.existsSync() ? f.path : null;
  }

  void enqueue(DownloadJob job) {
    if (_refuseIfNoEngine()) return;
    if (contains(job.videoId)) return;
    _errors.remove(job.videoId);
    _queue.add(job);
    notifyListeners();
    // ignore: discarded_futures
    _pump();
  }

  void remove(DownloadJob job) {
    if (_queue.remove(job)) notifyListeners();
  }

  Future<void> cancelCurrent() async {
    final job = _current;
    if (job == null) return;
    try {
      await Ytdlp.cancel(job.videoId);
    } catch (e) {
      debugPrint('[Sonarar][DL] cancel failed: ${job.videoId}: $e');
    }
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        _current = _queue.removeAt(0);
        notifyListeners();
        _startPolling(_current!);
        try {
          await _runOne(_current!);
        } catch (e, st) {
          debugPrint('[Sonarar][DL] failed ${_current?.videoId}: $e\n$st');
          final issue = e is DownloadBlocked
              ? DownloadIssue.blocked(e.kind)
              : DownloadIssue.failed(_short(e));
          _lastIssue = issue;
          final id = _current?.videoId;
          if (id != null) _errors[id] = issue;
          notifyListeners();
        } finally {
          _poll?.cancel();
          _poll = null;
          _current = null;
          notifyListeners();
        }
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _runOne(DownloadJob job) async {
    // Reading the library only needs the media grant; writing into it needs
    // all-files access. Catch that here instead of letting yt-dlp surface it as
    // a Python EPERM thirty seconds into the download.
    await _ensureWritable();
    log?.add('DL ${job.videoId}: dir ok (${_dir.path})');

    await Ytdlp.init();
    log?.add('DL ${job.videoId}: engine ready');
    final path = await Ytdlp.downloadAudio(
      url: 'https://www.youtube.com/watch?v=${job.videoId}',
      outputDir: _dir.path,
      taskId: job.videoId,

      // No -x, no --audio-format: ask for the best audio stream and keep its
      // own container. Transcoding was the only step that ran ffmpeg, and it
      // bought nothing the player cannot decode.
      format: 'bestaudio/best',
      onProgress: (p) {
        job.fraction = p.fraction;
        notifyListeners();
      },
    );

    log?.add('DL ${job.videoId}: wrote ${path.split('/').last}');
    final file = File(path);
    if (await file.length() == 0) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint(
          '[Sonarar][DL] empty file failed to delete: ${file.path}: $e',
        );
      }
      return;
    }

    final track = await describeDownload(
      audio: file,
      videoTitle: job.title,
      channel: job.channel,
      videoId: job.videoId,
      downloadDir: _dir,
      fetchThumbnail: httpGetBytes,
      thumbnailUrl: job.thumbnailUrl,
      durationSeconds: (job.duration ?? Duration.zero).inSeconds,
    );
    final manifest = manifestOf();
    if (track != null && manifest != null) {
      final filed = await addToManifest(manifest: manifest, track: track);
      log?.add('DL ${job.videoId}: manifest ${filed ? 'written' : 'REFUSED'}');
    }
    await onFiled?.call();
    log?.add('DL ${job.videoId}: done');
  }

  /// yt-dlp reports a missing grant as EPERM on the first write, which reads
  /// like a bug in the app. Probe the folder first so the message can say what
  /// to fix, and so an absent `Downloaded/` is created rather than failing.
  Future<void> _ensureWritable() => ensureDownloadReady(_dir, log: log);

  static String _short(Object e) {
    final line = e.toString().split('\n').first;
    return line.length <= 120 ? line : '${line.substring(0, 117)}…';
  }

  void _startPolling(DownloadJob job) {
    _poll = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (_current?.videoId != job.videoId) return;
      try {
        var total = 0;
        await for (final e in _dir.list()) {
          if (e is! File) continue;
          if (!e.uri.pathSegments.last.contains(job.videoId)) continue;
          total += await e.length();
        }
        if (total > 0) {
          job.bytes = total;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[Sonarar][DL] byte count failed: ${job.videoId}: $e');
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
