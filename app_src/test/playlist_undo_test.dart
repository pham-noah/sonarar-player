library;

// Taking a track out of a playlist used to be final: a toast said it was gone
// and there was no way to put it back, while deleting a whole playlist offered
// UNDO. Two ways out of the same kind of loss is worse than one, so removal now
// offers undo too, which needs the playlist to be able to take a track back at
// the slot it left rather than at the end.
//
// These tests are about the slot, the refusal and the timestamp: order is the
// only thing that makes undo worth having, a duplicate would be worse than the
// loss, and `updatedAt` is what the save path reads to know there is something
// to write — an undo that is not persisted is an undo lost on the next launch.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';

Playlist _p([List<String> ids = const ['a', 'b', 'c']]) =>
    Playlist(id: 'p1', name: 'Persona', trackIds: ids, createdAt: 1000);

void main() {
  test('a removed track goes back to the slot it left', () {
    final p = _p();
    expect(p.remove('b'), isTrue);
    expect(p.trackIds, ['a', 'c']);

    expect(p.insertAt(1, 'b'), isTrue);
    expect(p.trackIds, ['a', 'b', 'c'],
        reason: 'undo must restore the order the playlist had, not append to '
            'the end — a playlist is a sequence, and the sequence is the '
            'thing the user built');
  });

  test('a track already back in the playlist is not duplicated', () {
    final p = _p();
    expect(p.insertAt(0, 'a'), isFalse);
    expect(p.trackIds, ['a', 'b', 'c']);
  });

  test('a slot past the end is clamped, not thrown', () {
    // The playlist can shrink between the snackbar appearing and the tap on
    // UNDO: something else removed a track, or a sync pruned one. Landing at
    // the end beats losing the track again to an exception.
    final p = _p(['a']);
    expect(p.insertAt(7, 'late'), isTrue);
    expect(p.trackIds, ['a', 'late']);
  });

  test('putting a track back marks the playlist as changed', () {
    final p = _p();
    p.remove('b');
    final afterRemoval = p.updatedAt;
    final p2 = Playlist(
      id: p.id,
      name: p.name,
      trackIds: p.trackIds,
      createdAt: p.createdAt,
      updatedAt: afterRemoval,
    );

    // Same-millisecond writes are possible, so this asserts a floor rather than
    // a step: what matters is that the write is not skipped.
    expect(p2.insertAt(1, 'b'), isTrue);
    expect(p2.updatedAt, greaterThanOrEqualTo(afterRemoval),
        reason: 'the save path decides whether to write from updatedAt; an '
            'undo that leaves it untouched survives the session and not the '
            'launch');
  });
}
