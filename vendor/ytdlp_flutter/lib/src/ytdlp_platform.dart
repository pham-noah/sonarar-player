import 'models.dart';
import 'ytdlp_method_channel.dart';

/// Platform backend contract. Android uses the method-channel implementation
/// (Kotlin + youtubedl-android); iOS and macOS register Dart implementations
/// via `dartPluginClass`.
abstract class YtdlpPlatform {
  static YtdlpPlatform instance = MethodChannelYtdlp();

  /// Prepare the backend (extract binaries, boot the Python worker, download
  /// the yt-dlp binary…). Safe to call more than once.
  Future<void> init();

  /// Fetch metadata without downloading.
  Future<VideoInfo> getVideoInfo(String url);

  /// Download the best audio-only stream of [url] into [outputDir] and
  /// return the absolute path of the finished file.
  ///
  /// [format] is a yt-dlp format selector. [audioFormat] (e.g. `m4a`)
  /// triggers post-extraction with FFmpeg where the platform bundles one
  /// (Android); leave null to keep the native container.
  Future<String> downloadAudio(
    String url,
    String outputDir, {
    required String taskId,
    String format = 'bestaudio/best',
    String? audioFormat,
    void Function(YtdlpProgress progress)? onProgress,
  });

  /// Cancel a running download. Returns true if a task was found.
  Future<bool> cancel(String taskId);

  /// Update the yt-dlp engine in place. Returns a human-readable status.
  /// Throws [UnsupportedError] on iOS (App Store rule 2.5.2 forbids
  /// downloading executable code; ship updates with the app instead).
  Future<String> update();
}
