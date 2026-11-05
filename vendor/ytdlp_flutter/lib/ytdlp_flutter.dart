/// Run yt-dlp on-device: youtubedl-android on Android, the official
/// standalone binary on macOS, an embedded CPython on iOS.
library ytdlp_flutter;

import 'src/models.dart';
import 'src/ytdlp_platform.dart';

export 'src/models.dart';
export 'src/ytdlp_ios.dart' show YtdlpIos;
export 'src/ytdlp_macos.dart' show YtdlpMacos;
export 'src/ytdlp_platform.dart' show YtdlpPlatform;

/// Facade over the platform backends.
class Ytdlp {
  Ytdlp._();

  static YtdlpPlatform get _platform => YtdlpPlatform.instance;

  /// Prepare the engine. Call once early (idempotent); the first call may
  /// download/extract binaries or boot the embedded interpreter.
  static Future<void> init() => _platform.init();

  /// Fetch metadata for [url] without downloading anything.
  static Future<VideoInfo> getVideoInfo(String url) =>
      _platform.getVideoInfo(url);

  /// Download the best audio-only stream into [outputDir]; returns the
  /// finished file's absolute path. Keeps the native container (m4a/webm)
  /// unless [audioFormat] is set (Android only — needs bundled FFmpeg).
  static Future<String> downloadAudio({
    required String url,
    required String outputDir,
    String? taskId,
    String format = 'bestaudio/best',
    String? audioFormat,
    void Function(YtdlpProgress progress)? onProgress,
  }) {
    return _platform.downloadAudio(
      url,
      outputDir,
      taskId: taskId ?? 'dl-${DateTime.now().microsecondsSinceEpoch}',
      format: format,
      audioFormat: audioFormat,
      onProgress: onProgress,
    );
  }

  /// Cancel a running download by its [taskId].
  static Future<bool> cancel(String taskId) => _platform.cancel(taskId);

  /// Self-update the yt-dlp engine (Android, macOS). Throws
  /// [UnsupportedError] on iOS.
  static Future<String> update() => _platform.update();
}
