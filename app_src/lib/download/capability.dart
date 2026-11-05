library;

import 'engine_loader.dart';

/// Whether this build can download from YouTube at all.
///
/// The engine is yt-dlp running on a bundled CPython runtime: 14 MB of APK for a
/// feature many builds never use. A lite build compiles the runtime out and sets
/// `--dart-define=SONARAR_DOWNLOADS=false`, and every download affordance has to
/// disappear with it — a button that cannot work is worse than no button.
///
/// Deliberately a compile-time constant, not a runtime probe: the UI decides
/// during build, so there is no window where a button is drawn before the engine
/// has answered.
const bool kDownloadsCompiledIn = bool.fromEnvironment(
  'SONARAR_DOWNLOADS',
  defaultValue: true,
);

/// The engine a lite build fetches once, on the first download.
///
/// The archive is the arm64 payload lifted straight out of youtubedl-android, so
/// it is the same interpreter a full build would have shipped. The library marks
/// a payload stale by its byte length, which is why the install writes the length
/// of whatever archive it actually unpacked.
final EngineSource kHostedEngine = EngineSource(
  url: Uri.parse(
    'https://github.com/pham-noah/sonarar-player/releases/download/v0.3.2/libpython-arm64.zip',
  ),
  sha256: '7edecb6c9bd3a94456168d44911d8aea9f917bedef90c320a29500d92ac3eb62',
  version: 'yt-dlp 0.18.1',
);
