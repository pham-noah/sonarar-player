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
/// The engine a build without one fetches, per architecture.
///
/// The archives are lifted straight out of youtubedl-android, so they are the same
/// interpreters a full build would have shipped: arm64 for phones, x86_64 for
/// emulators and the x86 tablets/Chromebooks that still exist.
final Map<String, EngineSource> kHostedEngines = {
  'arm64-v8a': EngineSource(
    url: Uri.parse(_asset('libpython-arm64.zip')),
    sha256: '7edecb6c9bd3a94456168d44911d8aea9f917bedef90c320a29500d92ac3eb62',
    version: 'yt-dlp 0.18.1 (arm64)',
  ),
  'x86_64': EngineSource(
    url: Uri.parse(_asset('libpython-x86_64.zip')),
    sha256: '27caa316e09681ada860fdb6b35c1914e541e266e674141361758ac127fe2f15',
    version: 'yt-dlp 0.18.1 (x86_64)',
  ),
};

/// 32-bit devices run the armv7/x86 payloads the library also bundles; they are
/// rare enough that the arm64 archive is a poor fit but the only honest answer is
/// the nearest family rather than a silent wrong install.
const Map<String, String> _families = {
  'armeabi-v7a': 'arm64-v8a',
  'x86': 'x86_64',
};

String _asset(String name) =>
    'https://github.com/pham-noah/sonarar-player/releases/download/v0.3.2/$name';

/// The engine for [abi], or null when this architecture has none — better a clear
/// refusal than 14 MB of the wrong interpreter.
EngineSource? engineSourceFor(String? abi) {
  if (abi == null) return null;
  return kHostedEngines[abi] ?? kHostedEngines[_families[abi]];
}
