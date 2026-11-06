library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/engine_window.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/player/queue_edit.dart';
import 'package:sonarar/player/queue_mode.dart';

EngineEntry _e(String path) => (
      path: path,
      title: path,
      artist: 'A',
      album: 'B',
      cover: null,
    );

List<EngineEntry> _list(List<String> paths) => [for (final p in paths) _e(p)];

/// Replays [edits] against [from] the way the engine does, and returns the result.
///
/// This is the property that matters: whatever the diff says, applying it in order
/// has to produce the list that was asked for. A wrong index shows up here rather
/// than as music that stopped on a device.
List<String> _apply(List<String> from, List<QueueEdit> edits) {
  final out = List<String>.from(from);
  for (final edit in edits) {
    switch (edit) {
      case QueueRemove(:final index):
        out.removeAt(index);
      case QueueInsert(:final index, :final entry):
        out.insert(index, entry.path);
      case QueueMove(:final from, :final to):
        final moved = out.removeAt(from);
        out.insert(to, moved);
    }
  }
  return out;
}

void _expectTurnsInto(List<String> from, List<String> to, {String? reason}) {
  final edits = queueEditsFor(from: from, to: _list(to));
  expect(_apply(from, edits), to,
      reason: '${reason ?? ''} edits were $edits');
}

Track _t(String id) => Track(
      id: id,
      title: 'Track $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

List<Track> _many(int n) => List.generate(n, (i) => _t('t$i'));

List<String> _ids(PlayQueue q) => [for (final t in q.order) t.id];

/// The queue's own edit vocabulary, replayed against the one list.
///
/// These are the steps the UI performs, in the order the queue screen can perform
/// them. Before the collapse the play order and a source list were edited by hand in
/// parallel, so the interesting failure was never "wrong song" but "the two lists
/// disagree" — which only surfaced later, as a reload or a track that came back from
/// the dead. The assertions below are the engine-facing order plus membership.
void main() {
  group('the engine-queue diff', () {
    test('an unchanged queue needs no edits', () {
      expect(queueEditsFor(from: ['a', 'b'], to: _list(['a', 'b'])), isEmpty);
    });

    test('adding one to the end is ONE insert, nothing else', () {
      final edits = queueEditsFor(from: ['a', 'b'], to: _list(['a', 'b', 'c']));

      expect(edits, hasLength(1));
      expect(edits.single, isA<QueueInsert>());
      _expectTurnsInto(['a', 'b'], ['a', 'b', 'c']);
    });

    test('removing one from the middle is one removal', () {
      final edits = queueEditsFor(from: ['a', 'b', 'c'], to: _list(['a', 'c']));

      expect(edits, hasLength(1));
      expect(edits.single, isA<QueueRemove>());
      _expectTurnsInto(['a', 'b', 'c'], ['a', 'c']);
    });

    test('removing the tail is one removal at the last index', () {
      final edits = queueEditsFor(from: ['a', 'b', 'c'], to: _list(['a', 'b']));

      expect(edits, hasLength(1));
      expect((edits.single as QueueRemove).index, 2);
    });

    test('reordering is a move, not a rebuild', () {
      final edits = queueEditsFor(from: ['a', 'b', 'c'], to: _list(['b', 'a', 'c']));

      expect(edits, hasLength(1));
      expect(edits.single, isA<QueueMove>());
      _expectTurnsInto(['a', 'b', 'c'], ['b', 'a', 'c']);
    });

    test('an insertion in the middle puts it at that index', () {
      final edits = queueEditsFor(from: ['a', 'c'], to: _list(['a', 'b', 'c']));

      expect((edits.single as QueueInsert).index, 1);
      _expectTurnsInto(['a', 'c'], ['a', 'b', 'c']);
    });

    test('several edits at once still land on the wanted list', () {
      _expectTurnsInto(
        ['a', 'b', 'c', 'd', 'e'],
        ['e', 'b', 'x', 'd'],
        reason: 'remove a and c, insert x, move e to the front',
      );
    });

    test('a completely different queue replays correctly', () {
      _expectTurnsInto(['a', 'b', 'c'], ['x', 'y']);
    });

    test('an empty engine queue fills up', () {
      _expectTurnsInto([], ['a', 'b', 'c']);
    });

    test('the engine queue can be emptied', () {
      _expectTurnsInto(['a', 'b'], []);
    });

    test('a window that slid forward by one track replays correctly', () {
      // What a skip at the window's edge looks like: one out of the front, one in
      // at the back.
      _expectTurnsInto(
        [for (var i = 0; i < 24; i++) 't$i'],
        [for (var i = 1; i < 25; i++) 't$i'],
      );
    });

    test('the diff never removes and re-adds a path that is in both lists', () {
      final edits = queueEditsFor(
        from: ['a', 'b', 'c'],
        to: _list(['c', 'b', 'a']),
      );

      final removed = edits.whereType<QueueRemove>().map((e) => e.index).toSet();
      final inserted = edits.whereType<QueueInsert>().length;
      expect(inserted, 0, reason: 'nothing new arrived, so nothing should be inserted');
      expect(removed, isEmpty, reason: 'all three are still wanted');
      expect(edits.whereType<QueueMove>(), hasLength(2),
          reason: 'a reversal is moves, the cheapest thing that gets there');
    });

    test('indexOfPath finds the playing track where the engine will put it', () {
      expect(indexOfPath(_list(['a', 'b', 'c']), 'b'), 1);
      expect(indexOfPath(_list(['a']), 'gone'), -1);
    });
  });

  group('the queue edit vocabulary, on one list', () {
    test('play next is an edit: an unshuffle does not take it back', () {
      final q = PlayQueue(source: _many(4));

      q.playNext(_t('extra'));
      expect(_ids(q), ['t0', 'extra', 't1', 't2', 't3']);

      q.setShuffle(true);
      q.setShuffle(false);

      expect(_ids(q), ['t0', 'extra', 't1', 't2', 't3'],
          reason: '"play this next" survives a mode switch');
    });

    test('a drag is a view of the pass: unshuffling gives the arrangement back',
        () {
      final q = PlayQueue(source: _many(4));

      expect(q.move(0, 3), isTrue);
      expect(_ids(q), ['t1', 't2', 't3', 't0']);
      expect(q.current!.id, 't0', reason: 'reordering must not change the song');

      q.setShuffle(true);
      q.setShuffle(false);

      expect(_ids(q), ['t0', 't1', 't2', 't3'],
          reason: 'the arrangement is what a drag is drawn on top of');
    });

    test('clearing what is up next is final — no shuffle brings it back', () {
      final q = PlayQueue(source: _many(4));
      q.jumpTo('t1');

      expect(q.clearUpcoming(), 2);

      q.setShuffle(true);
      expect(_ids(q), unorderedEquals(['t0', 't1']),
          reason: 'the dropped tracks are gone from the pass AND the arrangement');
      q.setShuffle(false);
      expect(_ids(q), ['t0', 't1']);
      expect(q.length, 2);
    });

    test('replacing the current track swaps the slot and drops a second copy', () {
      final live = _t('t1-live');
      final q = PlayQueue(source: [..._many(4), live]);
      q.jumpTo('t1');

      expect(q.replaceCurrent(live), isTrue);

      expect(_ids(q), ['t0', 't1-live', 't2', 't3']);
      expect(q.index, 1, reason: 'the slot is where playback already is');
      expect(q.upcoming.map((t) => t.id), ['t2', 't3']);
    });

    test('a replacement that is already playing is not a change', () {
      final q = PlayQueue(source: _many(3));
      final version = q.orderVersion;

      expect(q.replaceCurrent(_t('t0')), isFalse);
      expect(q.orderVersion, version, reason: 'nothing moved, so the engine is fine');
    });

    test('shuffle on and off keeps every track exactly once and the song', () {
      final q = PlayQueue(source: _many(12), random: Random(11));
      q.next(wrap: true);
      q.next(wrap: true);
      final playing = q.current!.id;

      q.setShuffle(true);
      expect(_ids(q), unorderedEquals([for (var i = 0; i < 12; i++) 't$i']));
      expect(q.current!.id, playing);

      q.setShuffle(false);
      expect(_ids(q), [for (var i = 0; i < 12; i++) 't$i']);
      expect(q.current!.id, playing);
    });

    test('repeat one replays, repeat all wraps, off stops', () {
      final q = PlayQueue(source: _many(2));
      q.jumpTo('t1');
      expect(q.next(wrap: false), isNull, reason: 'the end of the pass');

      expect(
        advanceFor(
          mode: QueueMode.dynamic,
          repeatOne: true,
          repeatAll: false,
          hasNext: false,
        ),
        AutoAdvanceMode.replay,
      );
      expect(
        advanceFor(
          mode: QueueMode.dynamic,
          repeatOne: false,
          repeatAll: true,
          hasNext: false,
        ),
        AutoAdvanceMode.next,
        reason: 'repeat all is the wrap the next() call is told to take',
      );
      expect(
        advanceFor(
          mode: QueueMode.dynamic,
          repeatOne: false,
          repeatAll: false,
          hasNext: false,
        ),
        AutoAdvanceMode.stop,
      );

      expect(q.next(wrap: true)!.id, 't0', reason: 'the wrap it asked for');
      expect(canStepOutsideEngine(q, repeatAll: false, forward: true), isTrue);
    });

    test('no step in the vocabulary invents or loses a track', () {
      final q = PlayQueue(source: _many(6), random: Random(4));
      final expected = {for (var i = 0; i < 6; i++) 't$i'};

      void check(String step) {
        final ids = _ids(q);
        expect(ids.toSet(), expected, reason: '$step changed the membership');
        expect(ids.length, expected.length,
            reason: '$step left a track twice in the order');
        expect(q.length, expected.length, reason: '$step changed the length');
        expect(q.index, lessThan(q.length));
      }

      q.append(_t('t9'));
      expected.add('t9');
      check('add');

      q.jumpTo('t2');
      q.playNext(_t('t3'));
      check('play next');

      q.remove('t1');
      expected.remove('t1');
      check('remove');

      q.move(0, q.length - 1);
      check('move');

      q.replaceCurrent(_t('t2-live'));
      expected
        ..remove('t2')
        ..add('t2-live');
      check('replace current');

      q.setShuffle(true);
      check('shuffle on');

      q.next(wrap: true);
      q.next(wrap: true);
      check('skips inside a shuffled pass');

      q.setShuffle(false);
      check('shuffle off');

      q.clearUpcoming();
      expected.removeAll(expected.skip(q.index + 1).toSet());
      check('clear upcoming');
    });
  });
}
