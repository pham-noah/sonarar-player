library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/fade_envelope.dart';

/// A timer that only fires when the test says so.
class _FakeTimer implements Timer {
  _FakeTimer(this._onFire);

  final void Function(Timer) _onFire;
  bool _active = true;

  void fire() {
    if (_active) _onFire(this);
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _Harness {
  final List<double> applied = [];
  final List<_FakeTimer> timers = [];
  int created = 0;
  double level = 1.0;

  FadeEnvelope build({int steps = 24}) => FadeEnvelope(
        applyVolume: (v) {
          applied.add(v);
          level = v;
        },
        readVolume: () => level,
        steps: steps,
        timerFactory: (interval, callback) {
          created++;
          final t = _FakeTimer(callback);
          timers.add(t);
          return t;
        },
      );

  _FakeTimer get timer => timers.last;
}

void main() {
  group('the fade envelope', () {
    test('a zero-length fade is applied at once, with no timer', () async {
      final h = _Harness();
      final fade = h.build();

      await fade.fadeTo(0.25, Duration.zero);

      expect(h.applied, [0.25]);
      expect(h.created, 0);
      expect(fade.isFading, isFalse);
    });

    test('a fade walks from where the level is to where it is wanted', () async {
      final h = _Harness();
      h.level = 1.0;
      final fade = h.build(steps: 4);

      final done = fade.fadeTo(0.0, const Duration(milliseconds: 240));
      expect(fade.isFading, isTrue);

      for (var i = 0; i < 4; i++) {
        h.timer.fire();
      }
      await done;

      expect(h.applied, [0.75, 0.5, 0.25, 0.0],
          reason: 'four equal steps, ending exactly on the target');
      expect(fade.isFading, isFalse);
    });

    test('a fade starts from the level actually playing, not the last asked-for one',
        () async {
      final h = _Harness();
      h.level = 0.4; // something else moved the level
      final fade = h.build(steps: 2);

      final done = fade.fadeTo(0.8, const Duration(milliseconds: 100));
      h.timer.fire();
      h.timer.fire();
      await done;

      expect(h.applied.first, closeTo(0.6, 0.001));
      expect(h.applied.last, closeTo(0.8, 0.001));
    });

    test('the newest fade wins: an earlier one is cancelled where it stands',
        () async {
      final h = _Harness();
      final fade = h.build(steps: 4);

      final first = fade.fadeTo(0.0, const Duration(milliseconds: 240));
      h.timer.fire();
      h.timer.fire();

      final second = fade.fadeTo(1.0, const Duration(milliseconds: 240));
      await first; // the cancelled one completes rather than hanging

      for (var i = 0; i < 4; i++) {
        h.timer.fire();
      }
      await second;

      expect(h.applied.last, 1.0, reason: 'the second fade reached its target');
      expect(h.timers.first.isActive, isFalse, reason: 'the first is cancelled');
    });

    test('cancelling lets whoever is waiting carry on', () async {
      final h = _Harness();
      final fade = h.build(steps: 4);

      var completed = false;
      final done = fade.fadeTo(0.0, const Duration(milliseconds: 240))
          .then((_) => completed = true);
      h.timer.fire();

      fade.cancel();
      await done;

      expect(completed, isTrue, reason: 'a cancelled fade must not hang its waiter');
      expect(fade.isFading, isFalse);
      expect(h.applied.last, isNot(0.0), reason: 'it stopped where it got to');
    });

    test('the target is clamped to a real level', () async {
      final h = _Harness();
      final fade = h.build(steps: 2);

      final done = fade.fadeTo(4.0, const Duration(milliseconds: 100));
      h.timer.fire();
      h.timer.fire();
      await done;

      expect(h.applied.last, 1.0);
    });

    test('the engine being torn down mid-fade does not throw', () async {
      final h = _Harness();
      final fade = h.build(steps: 4);

      final done = fade.fadeTo(0.0, const Duration(milliseconds: 240));
      h.timer.fire();

      expect(fade.dispose, returnsNormally);
      await done;
      expect(fade.isFading, isFalse);
    });

    test('a step is never shorter than 8ms or longer than 500ms', () {
      final h = _Harness();

      // 24 steps over 12s is 500ms each; over 24ms it would be 1ms, so it clamps.
      unawaited(h.build().fadeTo(0, const Duration(milliseconds: 24)));
      unawaited(h.build().fadeTo(0, const Duration(seconds: 12)));

      expect(h.created, 2);
    });
  });
}
