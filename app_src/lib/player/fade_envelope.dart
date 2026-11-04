/// A fade: the engine's volume walked from where it is to where it is wanted, in
/// small steps, over a stated time.
///
/// This was four fields and two methods inside [AudioEngine] — a periodic timer,
/// a completer, a cancel flag and the level to fade back to — interleaved with
/// transport, audio focus and loop ticking. Nothing about it needs an engine, so
/// it takes the two things it does need (a way to set the level, a way to read
/// it), and the timer factory is injectable so a test can drive it by hand
/// instead of waiting two seconds of wall time.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

/// How many steps a fade is walked in. Twenty-four over 200ms is under 10ms a
/// step, which is smooth, and over 12s it is half a second, which is fine too.
const int kFadeSteps = 24;

typedef FadeTimerFactory = Timer Function(
  Duration interval,
  void Function(Timer timer) callback,
);

Timer _realPeriodic(Duration interval, void Function(Timer) callback) =>
    Timer.periodic(interval, callback);

class FadeEnvelope {
  FadeEnvelope({
    required this.applyVolume,
    required this.readVolume,
    this.steps = kFadeSteps,
    this.timerFactory = _realPeriodic,
  });

  /// Sets the engine's level. Errors are the engine's problem, not the fade's.
  final void Function(double volume) applyVolume;

  /// The level right now — the fade starts from what is actually playing, not
  /// from what was last asked for.
  final double Function() readVolume;

  final int steps;

  /// Where the timer comes from; a test passes one it can fire by hand.
  final FadeTimerFactory timerFactory;

  Timer? _timer;
  Completer<void>? _done;

  bool get isFading => _timer != null;

  /// Fades to [to] over [over], and completes when it arrives.
  ///
  /// A fade already in flight is cancelled first: the newest instruction wins,
  /// which is what stops a crossfade and a sleep fade fighting over the level.
  Future<void> fadeTo(double to, Duration over) async {
    cancel();
    final target = to.clamp(0.0, 1.0);
    if (over <= Duration.zero) {
      applyVolume(target);
      return;
    }

    final from = readVolume();
    final step = over.inMilliseconds ~/ steps;
    var i = 0;
    final done = Completer<void>();
    _done = done;
    _timer = timerFactory(Duration(milliseconds: step.clamp(8, 500)), (t) {
      i++;
      final f = (i / steps).clamp(0.0, 1.0);
      applyVolume((from + (target - from) * f).clamp(0.0, 1.0));
      if (i >= steps) {
        t.cancel();
        _timer = null;
        _done = null;
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  /// Stops wherever the level got to and lets whoever is waiting carry on.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  void dispose() {
    try {
      cancel();
    } catch (e) {
      // A cancelled fade completing into a torn-down engine must not throw.
      debugPrint('[Sonarar][FADE] cancel on dispose failed: $e');
    }
  }
}
