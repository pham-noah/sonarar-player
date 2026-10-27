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

  bool get isRunning => _startedAt != null && !_stopped;

  void start(DateTime now, Duration total) {
    _startedAt = now;
    _total = total;
    _stopped = false;
  }

  double cancel() {
    _startedAt = null;
    _stopped = false;
    _total = Duration.zero;
    return 1.0;
  }

  Duration? remaining(DateTime now) {
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
