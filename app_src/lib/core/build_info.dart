library;

/// What this build is, for the update check.
///
/// Read from a constant rather than a plugin: one number, no dependency, and a
/// test fails if it drifts from `pubspec.yaml`.
const String appVersionName = '0.3.1';
const int appVersionCode = 31;
