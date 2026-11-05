import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'ytdlp_ios.dart';
import 'ytdlp_platform.dart';

/// macOS backend registration. Inside a Flutter app, macOS uses the same
/// embedded-CPython worker as iOS ([YtdlpIos]): sandboxed apps cannot run
/// yt-dlp as a subprocess — runtime downloads get quarantined (exec EPERM)
/// and even a bundled PyInstaller binary dies on SysV semaphores inside the
/// sandbox. The macOS pod vendors Python.framework and the yt-dlp zipapp.
///
/// The [YtdlpMacos] class below drives the official standalone
/// `yt-dlp_macos` binary via [Process] instead. It only works unsandboxed
/// and exists for host-side tests (`flutter test` on a mac), which
/// instantiate it explicitly with [cacheDirOverride].
///
/// No FFmpeg is assumed: with the default `bestaudio/best` selector yt-dlp
/// downloads a single stream and no merge/extract step is needed. Pass
/// [audioFormat] only if the host has an ffmpeg on PATH.
class YtdlpMacos extends YtdlpPlatform {
  YtdlpMacos({this.cacheDirOverride, this.binaryUrl = defaultBinaryUrl});

  /// Registered by the Flutter tool via `dartPluginClass`. Registers the
  /// embedded-CPython worker client (shared with iOS), not this class.
  static void registerWith() {
    YtdlpPlatform.instance = YtdlpIos();
  }

  static const defaultBinaryUrl =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';

  /// Override the cache directory (used by tests, where path_provider's
  /// platform channel is unavailable).
  final String? cacheDirOverride;
  final String binaryUrl;

  final Map<String, Process> _running = {};
  String? _binaryPath;

  Future<String> _cacheDir() async {
    if (cacheDirOverride != null) return cacheDirOverride!;
    final support = await getApplicationSupportDirectory();
    return '${support.path}/ytdlp_flutter';
  }

  Future<String> _ensureBinary() async {
    if (_binaryPath != null && File(_binaryPath!).existsSync()) {
      return _binaryPath!;
    }
    final dir = Directory(await _cacheDir());
    await dir.create(recursive: true);
    final binary = File('${dir.path}/yt-dlp_macos');

    if (!binary.existsSync() || binary.lengthSync() == 0) {
      final tmp = File('${binary.path}.download');
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(binaryUrl));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw YtdlpException(
              'Failed to download yt-dlp binary (HTTP ${response.statusCode})');
        }
        await response.pipe(tmp.openWrite());
      } finally {
        client.close();
      }
      if (tmp.lengthSync() < 1024 * 1024) {
        throw const YtdlpException(
            'Downloaded yt-dlp binary is implausibly small');
      }
      await tmp.rename(binary.path);
      await Process.run('chmod', ['755', binary.path]);
      // Defensive: no-op unless something quarantined the file.
      await Process.run(
          'xattr', ['-d', 'com.apple.quarantine', binary.path]);
    }
    _binaryPath = binary.path;
    return binary.path;
  }

  @override
  Future<void> init() => _ensureBinary();

  @override
  Future<VideoInfo> getVideoInfo(String url) async {
    final bin = await _ensureBinary();
    final result = await Process.run(
        bin, ['--no-playlist', '-J', url]);
    if (result.exitCode != 0) {
      throw YtdlpException('yt-dlp -J failed (exit ${result.exitCode})',
          details: result.stderr.toString());
    }
    return VideoInfo.fromInfoDict(
        jsonDecode(result.stdout as String) as Map<String, dynamic>,
        keepRaw: true);
  }

  @override
  Future<String> downloadAudio(
    String url,
    String outputDir, {
    required String taskId,
    String format = 'bestaudio/best',
    String? audioFormat,
    void Function(YtdlpProgress progress)? onProgress,
  }) async {
    final bin = await _ensureBinary();
    await Directory(outputDir).create(recursive: true);

    // Machine-readable progress lines; 'NA' when a field is unknown.
    const progressTemplate = 'download:YTDLP_PROG '
        '%(progress.downloaded_bytes)s %(progress.total_bytes)s '
        '%(progress.total_bytes_estimate)s %(progress.eta)s';

    final args = <String>[
      '--no-playlist',
      '--newline',
      '-f', format,
      if (audioFormat != null) ...['-x', '--audio-format', audioFormat],
      '-o', '$outputDir/%(id)s.%(ext)s',
      '--no-simulate',
      '--print', 'after_move:filepath',
      '--progress',
      '--progress-template', progressTemplate,
      url,
    ];

    final process = await Process.start(bin, args);
    _running[taskId] = process;

    String? finalPath;
    final stderrBuf = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (line.startsWith('YTDLP_PROG ')) {
        final parts = line.substring('YTDLP_PROG '.length).split(' ');
        if (parts.length >= 4) {
          final downloaded = int.tryParse(parts[0]);
          final total = int.tryParse(parts[1]) ?? int.tryParse(parts[2]);
          onProgress?.call(YtdlpProgress(
            downloadedBytes: downloaded,
            totalBytes: total,
            fraction: (downloaded != null && total != null && total > 0)
                ? downloaded / total
                : null,
            etaSeconds: int.tryParse(parts[3]),
          ));
        }
      } else if (line.startsWith('/')) {
        // The '--print after_move:filepath' output — the finished file.
        finalPath = line.trim();
      }
    }).asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .listen(stderrBuf.write)
        .asFuture<void>();

    final exitCode = await process.exitCode;
    await Future.wait([stdoutDone, stderrDone]);
    final wasCancelled = _running.remove(taskId) == null;

    if (wasCancelled) throw YtdlpCancelledException(taskId);
    if (exitCode != 0) {
      throw YtdlpException('yt-dlp failed (exit $exitCode)',
          details: stderrBuf.toString());
    }
    if (finalPath == null || !File(finalPath!).existsSync()) {
      throw YtdlpException('yt-dlp finished but produced no file',
          details: stderrBuf.toString());
    }
    return finalPath!;
  }

  @override
  Future<bool> cancel(String taskId) async {
    final process = _running.remove(taskId);
    if (process == null) return false;
    process.kill();
    return true;
  }

  @override
  Future<String> update() async {
    final bin = await _ensureBinary();
    final result = await Process.run(bin, ['-U']);
    if (result.exitCode != 0) {
      throw YtdlpException('yt-dlp -U failed (exit ${result.exitCode})',
          details: result.stderr.toString());
    }
    return (result.stdout as String).trim();
  }
}
