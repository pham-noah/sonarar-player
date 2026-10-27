library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/player/playback_intent.dart';

void main() {
  group('a pause the app did not ask for is adopted, never overruled', () {
    test('stopped with nothing outstanding means the intent is to stop', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: false,
          retries: 0,
          completed: false,
        ),
        PlayAction.adoptStopped,
      );
    });

    test('and it stays adopted as the state settles', () {
      for (var i = 0; i < 10; i++) {
        expect(
          nextPlayAction(
            playing: false,
            outstanding: false,
            retries: 0,
            completed: false,
          ),
          PlayAction.adoptStopped,
        );
      }
    });
  });

  group('a dropped play call is still rescued', () {
    test('outstanding and stopped re-issues', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: true,
          retries: 0,
          completed: false,
        ),
        PlayAction.reissuePlay,
      );
    });

    test('it keeps trying, but only up to the budget', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: true,
          retries: kMaxPlayRetries - 1,
          completed: false,
        ),
        PlayAction.reissuePlay,
      );

      expect(
        nextPlayAction(
          playing: false,
          outstanding: true,
          retries: kMaxPlayRetries,
          completed: false,
        ),
        PlayAction.giveUp,
      );
    });

    test('once it starts, the window closes', () {
      expect(
        nextPlayAction(
          playing: true,
          outstanding: true,
          retries: 0,
          completed: false,
        ),
        PlayAction.adoptPlaying,
      );

      expect(
        nextPlayAction(
          playing: true,
          outstanding: false,
          retries: 5,
          completed: false,
        ),
        PlayAction.adoptPlaying,
      );
    });
  });

  group('completion', () {
    test('a finished track is not the intent\'s business', () {
      for (final outstanding in [true, false]) {
        expect(
          nextPlayAction(
            playing: false,
            outstanding: outstanding,
            retries: 0,
            completed: true,
          ),
          PlayAction.none,
        );
      }
    });

    test('a failed load is never reported as a finished track', () {
      expect(
        shouldReportCompletion(loadFailed: true, suppressNext: false),
        isFalse,
      );
    });

    test('the completion a platform skip lands on is swallowed exactly once', () {
      expect(
        shouldReportCompletion(loadFailed: false, suppressNext: true),
        isFalse,
      );
    });

    test('an ordinary finish is reported', () {
      expect(
        shouldReportCompletion(loadFailed: false, suppressNext: false),
        isTrue,
      );
    });
  });

  group('the distinction the old code lacked', () {
    test('the same player state decides two different things', () {
      final fromOutside = nextPlayAction(
        playing: false,
        outstanding: false,
        retries: 0,
        completed: false,
      );
      final fromDroppedCall = nextPlayAction(
        playing: false,
        outstanding: true,
        retries: 0,
        completed: false,
      );
      expect(fromOutside, isNot(fromDroppedCall));
      expect(fromOutside, PlayAction.adoptStopped);
      expect(fromDroppedCall, PlayAction.reissuePlay);
    });
  });
}
