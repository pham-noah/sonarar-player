library;

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
