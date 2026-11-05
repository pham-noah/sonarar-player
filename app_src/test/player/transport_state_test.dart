library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/playback_intent.dart';
import 'package:sonarar/player/transport_state.dart';

/// The state machine the engine's five booleans became.
///
/// Each test is one of the orders that actually happen on a device: a play asked for
/// while the file is still loading, a skip mid-song, the completion just_audio fires
/// for the track it was moved away from, and a play that the platform ignores.
void main() {
  group('a fresh transport', () {
    test('wants nothing and owes nothing', () {
      final t = TransportState();

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
      expect(t.isOutstanding, isFalse);
      expect(t.isSkipping, isFalse);
      expect(t.retries, 0);
      expect(t.owesCompletion, isFalse);
    });

    test('a state event that says "not playing" changes nothing', () {
      final t = TransportState();
      t.apply(t.actionFor(playing: false, loading: false));

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
    });
  });

  group('play during a load', () {
    test('the request stands while the file is still loading', () {
      final t = TransportState()..onPlayRequested();

      expect(t.phase, TransportPhase.requested);
      expect(t.wantsPlay, isTrue);
      expect(t.isOutstanding, isTrue);

      expect(t.actionFor(playing: false, loading: true), PlayAction.none,
          reason: 'loading is not a failed play, so nothing is reissued yet');
      expect(t.isOutstanding, isTrue, reason: 'the request is still outstanding');
    });

    test('the platform confirming settles it, and clears the retry count', () {
      final t = TransportState()..onPlayRequested();
      t.apply(t.actionFor(playing: false, loading: false));
      expect(t.retries, 1);

      t.apply(t.actionFor(playing: true, loading: false));

      expect(t.phase, TransportPhase.active);
      expect(t.wantsPlay, isTrue);
      expect(t.isOutstanding, isFalse);
      expect(t.retries, 0);
    });

    test('a queue handed over wants play without an outstanding request', () {
      final t = TransportState()..noteIntent();

      expect(t.phase, TransportPhase.active);
      expect(t.wantsPlay, isTrue);
      expect(t.isOutstanding, isFalse);
      expect(t.actionFor(playing: false, loading: false), PlayAction.adoptStopped,
          reason: 'nothing was asked of the platform, so nothing is retried');
    });
  });

  group('a play the platform ignores', () {
    test('is reissued a bounded number of times, then given up on', () {
      final t = TransportState()..onPlayRequested();

      var reissues = 0;
      while (t.actionFor(playing: false, loading: false) == PlayAction.reissuePlay) {
        t.apply(PlayAction.reissuePlay);
        reissues++;
        expect(reissues, lessThanOrEqualTo(kMaxPlayRetries));
      }

      expect(reissues, kMaxPlayRetries);
      t.apply(t.actionFor(playing: false, loading: false));

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse, reason: 'the engine is not going to start it');
      expect(t.retries, 0);
    });

    test('a pause during the request ends it rather than retrying it', () {
      final t = TransportState()..onPlayRequested();
      t.onPauseRequested();

      expect(t.isOutstanding, isFalse);
      expect(t.actionFor(playing: false, loading: false), PlayAction.adoptStopped);
    });
  });

  group('a skip', () {
    test('is in flight until the platform reports the move', () {
      final t = TransportState()..noteIntent();
      t.onSkipRequested();

      expect(t.phase, TransportPhase.skipping);
      expect(t.isSkipping, isTrue);
      expect(t.wantsPlay, isTrue, reason: 'a skip means carry on');
      expect(t.isOutstanding, isFalse,
          reason: 'no play was issued for the track we moved to');
    });

    test('landing keeps the intent to play', () {
      final t = TransportState()..noteIntent();
      t.onSkipRequested();

      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: true,
        platformCompleted: false,
      );

      expect(t.phase, TransportPhase.active);
      expect(t.isSkipping, isFalse, reason: 'the one move was accounted for');
      expect(t.wantsPlay, isTrue);
    });

    test('the completion it fires is not a track that ended', () {
      final t = TransportState()..noteIntent();
      t.onSkipRequested();
      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: true,
        platformCompleted: false,
      );

      expect(t.owesCompletion, isTrue);
      expect(t.onCompletedEvent(loadFailed: false), isFalse,
          reason: 'that completion belongs to the track that was skipped');
      expect(t.owesCompletion, isFalse, reason: 'the debt is paid once');
      expect(t.wantsPlay, isTrue,
          reason: 'a skipped track is not the end of playback');
    });

    test('the completion after that one IS counted', () {
      final t = TransportState()..noteIntent();
      t.onSkipRequested();
      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: true,
        platformCompleted: false,
      );
      t.onCompletedEvent(loadFailed: false);

      expect(t.onCompletedEvent(loadFailed: false), isTrue);
      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
    });
  });

  group('a source change we did not ask for', () {
    test('takes the intent from the platform, which is the only evidence there is',
        () {
      final t = TransportState()..noteIntent();

      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: false,
        platformCompleted: false,
      );

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
    });

    test('keeps playing when the platform kept playing', () {
      final t = TransportState()..noteIntent();

      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: true,
        platformCompleted: false,
      );

      expect(t.phase, TransportPhase.active);
      expect(t.wantsPlay, isTrue);
    });

    test('a move onto a finished queue does not invent an intent', () {
      final t = TransportState();
      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: false,
        platformCompleted: true,
      );

      expect(t.wantsPlay, isFalse);
      expect(t.owesCompletion, isTrue,
          reason: 'the completion for the item left behind still follows');
    });

    test('a report for the same item changes nothing', () {
      final t = TransportState()..noteIntent();
      t.onSourceChanged(
        platformMoved: false,
        platformPlaying: false,
        platformCompleted: false,
      );

      expect(t.phase, TransportPhase.active);
      expect(t.owesCompletion, isFalse);
    });
  });

  group('fade then stop', () {
    test('stopping ends the intent, so the next tick will not fade again', () {
      final t = TransportState()..noteIntent();
      expect(t.wantsPlay, isTrue);

      t.stopRequested();

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
    });
  });

  group('a load that failed', () {
    test('is not a track ending, and clears the intent', () {
      final t = TransportState()..onPlayRequested();

      expect(t.onCompletedEvent(loadFailed: true), isFalse);

      expect(t.phase, TransportPhase.idle);
      expect(t.wantsPlay, isFalse);
    });

    test('also pays off a completion that was owed', () {
      final t = TransportState()..noteIntent();
      t.onSourceChanged(
        platformMoved: true,
        platformPlaying: true,
        platformCompleted: false,
      );

      expect(t.onCompletedEvent(loadFailed: true), isFalse);
      expect(t.owesCompletion, isFalse);
    });
  });
}
