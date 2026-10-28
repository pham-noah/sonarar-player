library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/constants.dart';
import 'package:sonarar/playback/sleep_timer.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin_policy.dart';

void main() {
  group('sleep timer', () {
    final t0 = DateTime(2026, 10, 2, 23);

    test('full volume while far from the end', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 45));
      final tick = t.tick(t0.add(const Duration(minutes: 5)));
      expect(tick.action, SleepAction.fadeTo);
      expect(tick.volume, 1.0);
      expect(t.isRunning, isTrue);
    });

    test('it fades rather than cutting — that is the whole point', () {
      final t = SleepTimer(fade: const Duration(seconds: 20));
      t.start(t0, const Duration(minutes: 10));

      final tick = t.tick(t0.add(const Duration(minutes: 9, seconds: 50)));
      expect(tick.action, SleepAction.fadeTo);
      expect(tick.volume, closeTo(0.5, 0.01));
      expect(tick.action, isNot(SleepAction.stop));
    });

    test('the fade ramps monotonically down', () {
      final t = SleepTimer(fade: const Duration(seconds: 20));
      t.start(t0, const Duration(minutes: 1));
      var last = 1.1;
      for (var s = 0; s <= 20; s += 2) {
        final left = 20 - s;
        final tick = t.tick(
            t0.add(Duration(minutes: 1) - Duration(seconds: left)));
        if (tick.action == SleepAction.fadeTo) {
          expect(tick.volume, lessThanOrEqualTo(last));
          last = tick.volume;
        }
      }
      expect(last, lessThan(0.5));
    });

    test('it stops exactly once at the end', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 1));
      final end = t0.add(const Duration(minutes: 1));

      expect(t.tick(end).action, SleepAction.stop);

      expect(t.tick(end).action, SleepAction.none);
      expect(t.tick(end.add(const Duration(hours: 1))).action, SleepAction.none);
      expect(t.isRunning, isFalse);
      expect(t.remaining(end), isNull);
    });

    test('remaining never goes negative', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 1));
      expect(t.remaining(t0.add(const Duration(hours: 5))), Duration.zero);
    });

    test('starting again replaces the old timer rather than stacking', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 5));
      t.start(t0, const Duration(minutes: 60));
      expect(
        t.remaining(t0.add(const Duration(minutes: 10))),
        const Duration(minutes: 50),
      );
    });

    test('cancel restores full volume, so a cancelled fade does not deafen', () {
      final t = SleepTimer(fade: const Duration(seconds: 20));
      t.start(t0, const Duration(minutes: 10));
      final mid = t.tick(t0.add(const Duration(minutes: 9, seconds: 50)));
      expect(mid.volume, lessThan(1.0));

      expect(t.cancel(), 1.0);
      expect(t.isRunning, isFalse);
      expect(t.remaining(t0), isNull);

      expect(t.tick(t0).action, SleepAction.none);
    });

    test('the default fade is the app-wide constant, not a second number', () {
      final t = SleepTimer();
      expect(t.fade, kSleepFadeOut);
    });

    test('a timer never asked about does nothing', () {
      final t = SleepTimer();
      expect(t.isRunning, isFalse);
      expect(t.tick(t0).action, SleepAction.none);
      expect(t.remaining(t0), isNull);
    });

    test('pausing playback HOLDS the countdown instead of burning it', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 30));

      t.pause(t0.add(const Duration(minutes: 5)));
      expect(t.remaining(t0.add(const Duration(minutes: 25))),
          const Duration(minutes: 25),
          reason: 'paused time must not be spent');
      expect(t.isPaused, isTrue);

      t.resume(t0.add(const Duration(minutes: 25)));
      expect(t.remaining(t0.add(const Duration(minutes: 30))),
          const Duration(minutes: 20));
      expect(t.tick(t0.add(const Duration(minutes: 30))).action, SleepAction.fadeTo);
    });

    test('a paused timer does not fire on the first playable second', () {
      final t = SleepTimer(fade: const Duration(seconds: 10));
      t.start(t0, const Duration(minutes: 1));
      t.pause(t0.add(const Duration(seconds: 10)));
      t.resume(t0.add(const Duration(hours: 2)));

      expect(t.tick(t0.add(const Duration(hours: 2))).action, SleepAction.fadeTo);
      expect(t.tick(t0.add(const Duration(hours: 2))).volume, 1.0,
          reason: 'fifty seconds are left, so there is nothing to fade yet');
    });

    test('cancel forgets the paused state too', () {
      final t = SleepTimer();
      t.start(t0, const Duration(minutes: 10));
      t.pause(t0.add(const Duration(minutes: 1)));
      t.cancel();

      expect(t.remaining(t0), isNull);
      expect(t.isPaused, isFalse);
      expect(t.tick(t0).action, SleepAction.none);
    });
  });

  group('learning is REWARD ONLY', () {
    test('a skip is not recorded at all', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.evening, SkipFeedback.rejected);
      expect(m.rejections('t', ContextBand.evening), 0,
          reason: 'a skip was recorded, so it can still be punished later');
      expect(m.score('t', ContextBand.evening), 0);
    });

    test('NO amount of skipping suppresses a track', () {
      final m = FeedbackMemory();
      for (var i = 0; i < 20; i++) {
        m.record('t', ContextBand.evening, SkipFeedback.rejected);
      }
      expect(m.isSuppressed('t', ContextBand.evening), isFalse,
          reason: 'skipping still buries a track');
    });

    test('an acceptance is recorded and raises the score', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.night, SkipFeedback.accepted);
      expect(m.acceptances('t', ContextBand.night), 1);
      expect(m.score('t', ContextBand.night), 1);
    });

    test('the score can never go negative', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.night, SkipFeedback.rejected);
      m.record('t', ContextBand.night, SkipFeedback.rejected);
      m.record('t', ContextBand.night, SkipFeedback.accepted);
      expect(m.score('t', ContextBand.night), 1,
          reason: 'a rejection still subtracted from the score');
    });

    test('the same track in two bands stays two separate beliefs', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.evening, SkipFeedback.accepted);
      m.record('t', ContextBand.morning, SkipFeedback.accepted);
      expect(m.score('t', ContextBand.evening), 1);
      expect(m.score('t', ContextBand.morning), 1);
      expect(m.learned.length, 2);
    });

    test('forget still clears one track in one band', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.evening, SkipFeedback.accepted);
      m.record('t', ContextBand.night, SkipFeedback.accepted);
      m.forget('t', ContextBand.evening);
      expect(m.score('t', ContextBand.evening), 0);
      expect(m.score('t', ContextBand.night), 1);
    });

    test('a late skip records nothing — nothing was ever learned from it', () {
      final m = FeedbackMemory();
      m.record('t', ContextBand.evening, SkipFeedback.none);
      expect(m.score('t', ContextBand.evening), 0);
      expect(m.learned, isEmpty);
    });
  });
}
