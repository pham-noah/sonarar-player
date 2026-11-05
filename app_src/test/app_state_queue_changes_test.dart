library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

AppState _state([int n = 5]) => AppState()
  ..attachLibrary([for (var i = 0; i < n; i++) _t('t$i')]);

/// Which notifier an edit pings.
///
/// A queue edit is not a change to the app: the shell does not have to rebuild its
/// tabs and rails because a track moved up one place. Before this, every edit rebuilt
/// the whole tree, and the shell compensated by hand with its own `setState` after
/// every shuffle — which is what a missing distinction looks like.
void main() {
  late int wholeState;
  late int queueOnly;

  setUp(() {
    wholeState = 0;
    queueOnly = 0;
  });

  AppState watched([int n = 5]) {
    final state = _state(n);
    state.addListener(() => wholeState++);
    state.queueChanges.addListener(() => queueOnly++);
    return state;
  }

  group('an edit to the queue pings the queue, not the app', () {
    test('a reorder', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      expect(state.moveInQueue(1, 3), isTrue);

      expect(queueOnly, 1);
      expect(wholeState, 0, reason: 'the same tracks are playing in another order');
    });

    test('shuffle', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      state.toggleShuffle();

      expect(queueOnly, 1);
      expect(wholeState, 0);
    });

    test('repeat', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      state.cycleRepeat();

      expect(queueOnly, 1);
      expect(wholeState, 0);
    });

    test('adding, play-next and clearing what is up next', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      state.playTrackNow('t1');
      wholeState = 0;
      queueOnly = 0;

      expect(state.addToQueue(_t('extra')), isTrue);
      expect(state.playNextInQueue(_t('next')), isTrue);
      expect(state.clearUpcoming(), greaterThan(0));

      expect(queueOnly, 3);
      expect(wholeState, 0);
    });

    test('removing a track that is not the one playing', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      state.playTrackNow('t0');
      wholeState = 0;
      queueOnly = 0;

      expect(state.removeFromQueue('t3'), isFalse, reason: 't3 was not playing');

      expect(queueOnly, 1);
      expect(wholeState, 0);
    });

    test('putting a removed track back', () {
      final state = watched();
      final gone = _t('t3');
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      state.removeFromQueue('t3');
      wholeState = 0;
      queueOnly = 0;

      expect(state.restoreToQueue(3, gone), isTrue);

      expect(queueOnly, 1);
      expect(wholeState, 0);
    });
  });

  group('a change that moves the song pings the app', () {
    test('skipping to the next track', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      state.advance();

      expect(wholeState, greaterThan(0),
          reason: 'the shell shows what is playing; that changed');
    });

    test('removing the track that is playing', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      state.playTrackNow('t2');
      wholeState = 0;
      queueOnly = 0;

      expect(state.removeFromQueue('t2'), isTrue,
          reason: 'it was the playing track');

      expect(wholeState, greaterThan(0),
          reason: 'something else is playing now, and the shell has to know');
    });
  });

  group('an edit that changed nothing pings nothing', () {
    test('a move out of range', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      expect(state.moveInQueue(-1, 0), isFalse);

      expect(queueOnly, 0);
      expect(wholeState, 0);
    });

    test('adding a track that is already queued', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      wholeState = 0;
      queueOnly = 0;

      expect(state.addToQueue(_t('t1')), isFalse);

      expect(queueOnly, 0);
      expect(wholeState, 0);
    });

    test('a repeat mode that is already set', () {
      final state = watched();
      state.setQueueForTest([for (var i = 0; i < 5; i++) _t('t$i')]);
      state.setRepeat(RepeatMode.all);
      wholeState = 0;
      queueOnly = 0;

      state.setRepeat(RepeatMode.all);

      expect(queueOnly, 0);
      expect(wholeState, 0);
    });
  });
}
