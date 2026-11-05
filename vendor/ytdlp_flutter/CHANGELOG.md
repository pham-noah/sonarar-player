## 0.1.0

- Initial release.
- Android: youtubedl-android 0.18.1 (bundled Python + FFmpeg, runtime
  yt-dlp updates), method-channel backend with progress events.
- macOS: pure-Dart backend driving the official self-updating
  `yt-dlp_macos` standalone binary via `Process`.
- iOS (experimental): embedded CPython 3.13 (Python-Apple-support) running
  a bundled yt-dlp zipapp, file-based job protocol.
