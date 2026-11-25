library;

/// The wall clock, in one place.
///
/// The home page greets you by the hour and the skin tints by the same band, so
/// a screenshot of the shell is only stable if the hour is. It was not: the
/// shell golden passed at 02:00 (night) and failed at 06:44 (morning) with no
/// code change in between, because the greeting had moved a band. Reading the
/// clock through this hook lets a test pin the hour and lets the app otherwise
/// behave exactly as before.
class Clock {
  Clock._();

  /// What `now()` returns. Tests replace it and put `DateTime.now` back in
  /// `tearDown`; nothing else should assign it.
  static DateTime Function() now = DateTime.now;

  /// The current wall clock time.
  static DateTime call() => now();

  /// The current hour, 0-23.
  static int get hour => now().hour;
}
