/// The clock the player runs on: one periodic timer, started when there is
/// something worth watching and stopped when there is not.
///
/// The shell used to carry this as a `Timer?`, a `ValueNotifier<bool>` nobody
/// listened to, and a getter, with start and stop logic spread across three
/// methods. It is one object now, and the timer factory is injectable so the
/// start/stop/replace behaviour can be tested without waiting on wall time.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier;

/// How often the player reads the engine while something is playing.
const Duration kPlaybackTick = Duration(milliseconds: 250);

typedef PeriodicTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

Timer _realPeriodic(Duration interval, void Function(Timer) callback) =>
    Timer.periodic(interval, callback);

class PlaybackTicker {
  PlaybackTicker(
    this.onTick, {
    this.interval = kPlaybackTick,
    this.timerFactory = _realPeriodic,
  });

  /// Called once per [interval] while the ticker is running.
  final void Function() onTick;

  final Duration interval;

  /// Where the timer comes from; a test passes one it can drive by hand.
  final PeriodicTimerFactory timerFactory;

  Timer? _timer;

  /// True when the ticker was last told to run, whether or not a timer is live —
  /// a tick can stop the clock from inside itself.
  final ValueNotifier<bool> wanted = ValueNotifier<bool>(false);

  bool get isRunning => _timer != null;

  /// Starts the ticker when [run] and it is not running, stops it when not
  /// [run] and it is. Calling it twice with the same answer does nothing, so a
  /// state change that happens every frame does not restart the clock.
  void sync({required bool run}) {
    wanted.value = run;
    if (run) {
      if (_timer != null) return;
      _timer = timerFactory(interval, (_) => onTick());
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  /// Replaces a running timer without changing whether the ticker runs.
  void restart() {
    final run = wanted.value;
    _timer?.cancel();
    _timer = null;
    if (run) sync(run: true);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    wanted.dispose();
  }
}
