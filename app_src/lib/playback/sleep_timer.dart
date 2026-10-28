library;

import '../core/constants.dart';

enum SleepAction {
  none,

  fadeTo,

  stop,
}

class SleepTick {
  const SleepTick(this.action, [this.volume = 1.0]);

  final SleepAction action;
  final double volume;
}

class SleepTimer {
  SleepTimer({this.fade = kSleepFadeOut});

  final Duration fade;

  DateTime? _startedAt;
  Duration _total = Duration.zero;
  bool _stopped = false;

  DateTime? _pausedAt;
  Duration? _held;

  bool get isRunning => _startedAt != null && !_stopped;
  bool get isPaused => _pausedAt != null;

  void start(DateTime now, Duration total) {
    _startedAt = now;
    _total = total;
    _stopped = false;
    _pausedAt = null;
    _held = null;
  }

  /// Playback stopped, so the countdown does; resuming later must not end it.
  void pause(DateTime now) {
    if (_startedAt == null || _stopped || _pausedAt != null) return;
    // Read the clock before flagging the pause: remaining() then reports _held.
    final left = remaining(now);
    _pausedAt = now;
    _held = left ?? Duration.zero;
  }

  void resume(DateTime now) {
    final held = _held;
    if (_pausedAt == null || held == null) return;
    _startedAt = now;
    _total = held;
    _pausedAt = null;
    _held = null;
  }

  double cancel() {
    _startedAt = null;
    _stopped = false;
    _total = Duration.zero;
    _pausedAt = null;
    _held = null;
    return 1.0;
  }

  Duration? remaining(DateTime now) {
    if (_pausedAt != null) return _held;
    final started = _startedAt;
    if (started == null || _stopped) return null;
    final left = _total - now.difference(started);
    return left.isNegative ? Duration.zero : left;
  }

  SleepTick tick(DateTime now) {
    final started = _startedAt;
    if (started == null || _stopped) return const SleepTick(SleepAction.none);

    final left = remaining(now)!;

    if (left == Duration.zero) {
      _stopped = true;
      return const SleepTick(SleepAction.stop, 0.0);
    }

    if (left <= fade) {
      final f = left.inMilliseconds / fade.inMilliseconds;
      return SleepTick(SleepAction.fadeTo, f.clamp(0.0, 1.0));
    }

    return const SleepTick(SleepAction.fadeTo, 1.0);
  }
}
