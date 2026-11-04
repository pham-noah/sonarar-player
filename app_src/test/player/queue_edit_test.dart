library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/engine_window.dart';
import 'package:sonarar/player/queue_edit.dart';

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
}
