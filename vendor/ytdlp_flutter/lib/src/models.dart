/// Metadata for a single video, normalized across the three platform
/// backends (all of them ultimately produce yt-dlp's info-dict keys).
class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    this.durationSeconds,
    this.uploader,
    this.thumbnailUrl,
    this.webpageUrl,
    this.ext,
    this.raw,
  });

  final String id;
  final String title;
  final double? durationSeconds;
  final String? uploader;
  final String? thumbnailUrl;
  final String? webpageUrl;
  final String? ext;

  /// The full yt-dlp info dict when the backend provides it (Android and
  /// macOS do; the iOS worker returns only the normalized subset).
  final Map<String, dynamic>? raw;

  factory VideoInfo.fromInfoDict(Map<String, dynamic> json,
      {bool keepRaw = false}) {
    return VideoInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? json['id'] ?? '').toString(),
      durationSeconds: (json['duration'] as num?)?.toDouble(),
      uploader: json['uploader'] as String?,
      thumbnailUrl: json['thumbnail'] as String?,
      webpageUrl: json['webpage_url'] as String?,
      ext: json['ext'] as String?,
      raw: keepRaw ? json : null,
    );
  }

  @override
  String toString() =>
      'VideoInfo(id: $id, title: "$title", duration: ${durationSeconds}s)';
}

/// Download progress. Not every backend can fill every field: Android's
/// youtubedl-android reports a percentage and ETA, macOS/iOS report bytes.
/// What this build can actually do, asked before promising anything.
///
/// A lite build ships no Python runtime and no ffmpeg; both are reported here
/// so the app can hide a download button instead of failing after the tap.
class YtdlpCapabilities {
  const YtdlpCapabilities({
    this.engine = true,
    this.engineError,
    this.ffmpeg = false,
    this.ffmpegError,
    this.updated = 'unknown',
    this.version = 'unknown',
    this.abi,
  });

  /// The yt-dlp engine itself (needs the Python runtime on Android).
  final bool engine;
  final String? engineError;

  /// Whether post-processing (merge, transcode, HLS) is available.
  final bool ffmpeg;
  final String? ffmpegError;

  /// Result of the last in-place yt-dlp update, and the engine version.
  final String updated;
  final String version;

  /// The device's primary ABI, e.g. `arm64-v8a` or `x86_64`. The engine archive
  /// has to match it.
  final String? abi;

  factory YtdlpCapabilities.fromMap(Map<Object?, Object?> m) => YtdlpCapabilities(
        engine: m['engine'] as bool? ?? true,
        engineError: m['engineError'] as String?,
        ffmpeg: m['ffmpeg'] as bool? ?? false,
        ffmpegError: m['ffmpegError'] as String?,
        updated: m['updated'] as String? ?? 'unknown',
        version: m['version'] as String? ?? 'unknown',
        abi: m['abi'] as String?,
      );

  @override
  String toString() =>
      'YtdlpCapabilities(engine: $engine, ffmpeg: $ffmpeg, version: $version, abi: $abi)';
}

class YtdlpProgress {
  const YtdlpProgress({
    this.fraction,
    this.downloadedBytes,
    this.totalBytes,
    this.etaSeconds,
  });

  /// 0.0–1.0, when known.
  final double? fraction;
  final int? downloadedBytes;
  final int? totalBytes;
  final int? etaSeconds;

  @override
  String toString() {
    final pct = fraction != null
        ? '${(fraction! * 100).toStringAsFixed(1)}%'
        : '?%';
    return 'YtdlpProgress($pct, $downloadedBytes/$totalBytes, eta ${etaSeconds}s)';
  }
}

class YtdlpException implements Exception {
  const YtdlpException(this.message, {this.details});
  final String message;
  final String? details;

  @override
  String toString() =>
      'YtdlpException: $message${details != null ? '\n$details' : ''}';
}

class YtdlpCancelledException extends YtdlpException {
  const YtdlpCancelledException(String taskId)
      : super('Download cancelled: $taskId');
}
