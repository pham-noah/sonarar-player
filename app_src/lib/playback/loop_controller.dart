library;

import 'loop_points.dart';

enum LoopAction {
  none,

  seekToLoopStart,

  fadeOut,
}

class LoopController {
  LoopController({this.points});

  final LoopPoints? points;

  int _completed = 0;

  bool _fading = false;

  bool get hasLoop => points?.hasLoop ?? false;

  int get completedLoops => _completed;

  Duration get firstPlayStart => Duration.zero;

  Duration get resumePosition => points?.introEnd ?? Duration.zero;

  LoopAction decide({
    required Duration position,
    required Duration duration,
  }) {
    final p = points;
    if (p == null || !p.hasLoop) return LoopAction.none;

    if (_fading) return LoopAction.none;

    final loopEnd = p.loopEnd!;

    if (position >= loopEnd) {
      if (_completed < p.loopCount) {
        _completed++;
        return LoopAction.seekToLoopStart;
      }
      _fading = true;
      return LoopAction.fadeOut;
    }

    return LoopAction.none;
  }

  void reset() {
    _completed = 0;
    _fading = false;
  }
}
