library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

import '../library/downloaded_tracks.dart';
import '../library/library_repository.dart';

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

class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.repo,
    required this.downloadDirOf,
    required this.manifestOf,
    this.onFiled,
  });

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

  final List<DownloadJob> _queue = [];
  DownloadJob? _current;
  Timer? _poll;
  bool _running = false;

  DownloadJob? get current => _current;

  List<DownloadJob> get queue => List.unmodifiable(_queue);

  int get pendingCount => _queue.length;

  bool get isBusy => _current != null;

  List<DownloadJob> get all => [if (_current != null) _current!, ..._queue];

  bool contains(String videoId) =>
      _current?.videoId == videoId || _queue.any((j) => j.videoId == videoId);

  String? coverPathForJob(DownloadJob job) {
    final dir = _dirCache ?? downloadDirOf();
    if (dir == null) return null;
    final f = File('${dir.path}${Platform.pathSeparator}${job.videoId}.jpg');
    return f.existsSync() ? f.path : null;
  }

  void enqueue(DownloadJob job) {
    if (contains(job.videoId)) return;
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
    } catch (_) {
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
        } catch (e) {
          debugPrint('[Sonarar][DL] failed ${_current?.videoId}: $e');
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
    await Ytdlp.init();
    final path = await Ytdlp.downloadAudio(
      url: 'https://www.youtube.com/watch?v=${job.videoId}',
      outputDir: _dir.path,
      taskId: job.videoId,

      audioFormat: 'm4a',
      onProgress: (p) {
        job.fraction = p.fraction;
        notifyListeners();
      },
    );

    final file = File(path);
    if (await file.length() == 0) {
      try {
        await file.delete();
      } catch (_) {}
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
      await addToManifest(manifest: manifest, track: track);
    }
    await onFiled?.call();
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
      } catch (_) {
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
