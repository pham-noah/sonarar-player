import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'ytdlp_platform.dart';

/// Embedded-CPython backend for iOS and macOS: a bundled yt-dlp runs inside
/// the app process (BeeWare Python-Apple-support). The native side only
/// boots the interpreter and runs `worker.py`, which serves jobs over a
/// file-based protocol in Application Support — no Python C API crosses the
/// channel. In-process matters on macOS too: sandboxed apps cannot exec
/// yt-dlp as a subprocess (quarantine EPERM / PyInstaller SysV semaphores).
///
/// Protocol (rooted at `<Application Support>/ytdlp_flutter_worker/`):
///   jobs/<id>.json          job request, written by Dart, deleted by worker
///   out/<id>.progress.json  progress snapshots, written by worker
///   out/<id>.result.json    terminal result, written by worker
///   out/<id>.cancel         cancel flag, written by Dart
///   out/worker.alive        heartbeat, touched by the worker loop
///
/// yt-dlp is bundled (a .pyz inside the app), never downloaded: App Store
/// rule 2.5.2 forbids fetching executable code, so [update] is unsupported —
/// ship a new app build to update the extractor.
class YtdlpIos extends YtdlpPlatform {
  /// Registered by the Flutter tool via `dartPluginClass`.
  static void registerWith() {
    YtdlpPlatform.instance = YtdlpIos();
  }

  static const _channel = MethodChannel('ytdlp_flutter');

  Directory? _root;
  bool _workerStarted = false;

  Future<Directory> _workerRoot() async {
    if (_root != null) return _root!;
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/ytdlp_flutter_worker');
    await Directory('${root.path}/jobs').create(recursive: true);
    await Directory('${root.path}/out').create(recursive: true);
    _root = root;
    return root;
  }

  @override
  Future<void> init() async {
    if (_workerStarted) return;
    final root = await _workerRoot();
    await _channel.invokeMethod<void>('startWorker', {
      'workerDir': root.path,
    });
    // Wait for the interpreter to come up and touch its heartbeat.
    final alive = File('${root.path}/out/worker.alive');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!alive.existsSync()) {
      if (DateTime.now().isAfter(deadline)) {
        throw const YtdlpException(
            'Embedded Python worker did not start within 30s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _workerStarted = true;
  }

  Future<Map<String, dynamic>> _runJob(
    Map<String, dynamic> job, {
    void Function(YtdlpProgress)? onProgress,
  }) async {
    await init();
    final root = await _workerRoot();
    final id = job['id'] as String;
    final resultFile = File('${root.path}/out/$id.result.json');
    final progressFile = File('${root.path}/out/$id.progress.json');
    final staleCancel = File('${root.path}/out/$id.cancel');
    if (resultFile.existsSync()) resultFile.deleteSync();
    if (progressFile.existsSync()) progressFile.deleteSync();
    if (staleCancel.existsSync()) staleCancel.deleteSync();

    // Write atomically: the worker must never read a half-written job.
    final tmp = File('${root.path}/jobs/$id.json.tmp');
    await tmp.writeAsString(jsonEncode(job), flush: true);
    await tmp.rename('${root.path}/jobs/$id.json');

    String lastProgress = '';
    while (true) {
      if (resultFile.existsSync()) {
        final text = await resultFile.readAsString();
        if (text.isNotEmpty) {
          final result = jsonDecode(text) as Map<String, dynamic>;
          resultFile.deleteSync();
          if (progressFile.existsSync()) progressFile.deleteSync();
          if (result['ok'] == true) {
            return (result['data'] as Map?)?.cast<String, dynamic>() ?? {};
          }
          final error = (result['error'] ?? 'unknown error').toString();
          if (result['cancelled'] == true) {
            throw YtdlpCancelledException(id);
          }
          throw YtdlpException(error);
        }
      }
      if (onProgress != null && progressFile.existsSync()) {
        try {
          final text = await progressFile.readAsString();
          if (text.isNotEmpty && text != lastProgress) {
            lastProgress = text;
            final p = jsonDecode(text) as Map<String, dynamic>;
            final downloaded = (p['downloaded'] as num?)?.toInt();
            final total = (p['total'] as num?)?.toInt();
            onProgress(YtdlpProgress(
              downloadedBytes: downloaded,
              totalBytes: total,
              fraction: (downloaded != null && total != null && total > 0)
                  ? downloaded / total
                  : null,
              etaSeconds: (p['eta'] as num?)?.toInt(),
            ));
          }
        } catch (_) {
          // Snapshot mid-write; the next poll gets a complete one.
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  @override
  Future<VideoInfo> getVideoInfo(String url) async {
    final data = await _runJob({
      'id': 'info-${DateTime.now().microsecondsSinceEpoch}',
      'op': 'info',
      'url': url,
    });
    return VideoInfo.fromInfoDict(data);
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
    if (audioFormat != null) {
      throw const YtdlpException(
          'audioFormat needs FFmpeg, which is not bundled on iOS — '
          'download the native container and convert in the app');
    }
    await Directory(outputDir).create(recursive: true);
    final data = await _runJob({
      'id': taskId,
      'op': 'download',
      'url': url,
      'output_dir': outputDir,
      'format': format,
    }, onProgress: onProgress);
    final path = data['filepath'] as String?;
    if (path == null || !File(path).existsSync()) {
      throw const YtdlpException('Worker finished but produced no file');
    }
    return path;
  }

  @override
  Future<bool> cancel(String taskId) async {
    final root = await _workerRoot();
    final flag = File('${root.path}/out/$taskId.cancel');
    if (flag.existsSync()) return false;
    await flag.writeAsString('1', flush: true);
    return true;
  }

  @override
  Future<String> update() async {
    throw UnsupportedError(
        'yt-dlp cannot self-update on iOS (App Store rule 2.5.2). '
        'Update the bundled yt-dlp by shipping a new app build.');
  }
}
