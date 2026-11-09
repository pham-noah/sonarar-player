// Property-based abuse of PlayQueue: thousands of random edits, checked against
// the invariants every screen and the audio engine rely on.
@Tags(['adversarial'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';

Track t(int i) => Track(
      id: 't$i',
      title: 'Track $i',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
      file: 'a/$i.mp3',
      cover: 'a/$i.jpg',
      gainDb: null,
    );

void check(PlayQueue q, {required String where}) {
  final order = q.order;
  if (order.isEmpty) {
    expect(q.isEmpty, isTrue, reason: where);
    expect(q.index, 0, reason: '$where: empty queue index should rest at 0');
    expect(q.current, isNull, reason: where);
    expect(q.upcoming, isEmpty, reason: where);
    expect(q.played, isEmpty, reason: where);
    return;
  }

  expect(q.isEmpty, isFalse, reason: where);
  expect(q.index, inInclusiveRange(0, order.length - 1),
      reason: '$where: index ${q.index} out of range for ${order.length}');

  final ids = order.map((e) => e.id).toList();
  expect(ids.toSet().length, ids.length, reason: '$where: duplicate ids $ids');

  expect(q.current!.id, ids[q.index], reason: '$where: current is not order[index]');
  expect(q.upcoming.map((e) => e.id).toList(), ids.sublist(q.index + 1),
      reason: '$where: upcoming is not the tail');
  expect(q.played.map((e) => e.id).toList(), ids.sublist(0, q.index),
      reason: '$where: played is not the head');
  expect(q.upcoming.length, order.length - q.index - 1, reason: where);
  expect(q.played.length, q.index, reason: where);
}

void main() {
  test('random edit storms never break the queue invariants', () {
    for (var seed = 0; seed < 12; seed++) {
      final rng = Random(seed);
      final pool = [for (var i = 0; i < 24; i++) t(i)];
      final q = PlayQueue(
        source: pool.take(1 + rng.nextInt(24)).toList(),
        random: rng,
        shuffle: rng.nextBool(),
      );
      check(q, where: 'seed $seed initial');

      for (var step = 0; step < 500; step++) {
        final op = rng.nextInt(14);
        final where = 'seed $seed step $step op$op';
        final n = q.length;
        // Real callers hand the queue a library slice or a selection: ids are
        // unique on the way in. Duplicate injection is tested on its own below.
        List<Track> uniqueFew() => {
              for (var i = 0; i < rng.nextInt(4); i++) pool[rng.nextInt(pool.length)]
            }.toList();
        switch (op) {
          case 0:
            q.next(wrap: rng.nextBool());
          case 1:
            q.previous();
          case 2:
            q.jumpTo('t${rng.nextInt(30)}');
          case 3:
            q.move(rng.nextInt(30) - 5, rng.nextInt(30) - 5);
          case 4:
            q.remove('t${rng.nextInt(30)}');
          case 5:
            q.insertAt(rng.nextInt(40) - 10, pool[rng.nextInt(pool.length)]);
          case 6:
            q.clearUpcoming();
          case 7:
            q.setShuffle(rng.nextBool());
          case 8:
            q.append(pool[rng.nextInt(pool.length)]);
          case 9:
            q.playNext(pool[rng.nextInt(pool.length)]);
          case 10:
            q.promoteToNext(uniqueFew());
          case 11:
            q.replaceCurrent(pool[rng.nextInt(pool.length)]);
          case 12:
            q.restoreOrder([
              for (var i = 0; i < rng.nextInt(30); i++)
                rng.nextInt(6) == 0 ? 'ghost' : 't${rng.nextInt(30)}',
            ]);
          case 13:
            if (rng.nextInt(8) == 0) {
              q.replaceSource(uniqueFew(), keepPlaying: rng.nextBool());
            }
        }
        check(q, where: where);
        if (n == 0 && q.length > 0) {
          expect(q.index, 0, reason: '$where: first track must be the current one');
        }
      }
    }
  });

  test('clearUpcoming leaves exactly the playing track and the past', () {
    final q = PlayQueue(source: [for (var i = 0; i < 8; i++) t(i)]);
    q.next(wrap: false);
    q.next(wrap: false);
    final dropped = q.clearUpcoming();
    expect(dropped, 5);
    expect(q.length, 3);
    expect(q.index, 2);
    expect(q.current!.id, 't2');
    check(q, where: 'after clearUpcoming');
  });

  test('removing the playing track keeps a valid current', () {
    final q = PlayQueue(source: [for (var i = 0; i < 4; i++) t(i)]);
    q.next(wrap: false);
    q.next(wrap: false);
    final was = q.current!;
    expect(q.remove(was.id), isTrue);
    check(q, where: 'removed current');
    expect(q.current, isNotNull, reason: 'the player was left with nothing to show');
  });

  test('removing the last queued track empties cleanly', () {
    final q = PlayQueue(source: [t(1)]);
    q.remove('t1');
    check(q, where: 'emptied');
    expect(q.next(wrap: true), isNull);
    expect(q.previous(), isNull);
  });

  test('an out-of-range move is refused without corrupting the order', () {
    final q = PlayQueue(source: [for (var i = 0; i < 3; i++) t(i)]);
    final before = q.order.map((e) => e.id).toList();
    expect(q.move(-1, 0), isFalse);
    expect(q.move(0, 99), isFalse);
    expect(q.move(99, 0), isFalse);
    expect(q.order.map((e) => e.id).toList(), before);
    check(q, where: 'after refused moves');
  });

  test('jumping to an unknown track does not move the needle', () {
    final q = PlayQueue(source: [for (var i = 0; i < 3; i++) t(i)]);
    final at = q.index;
    expect(q.jumpTo('not-here'), isFalse);
    expect(q.index, at);
  });

  test('a restored order of only ghosts leaves the queue intact', () {
    final q = PlayQueue(source: [for (var i = 0; i < 3; i++) t(i)]);
    final before = q.order.map((e) => e.id).toList();
    q.restoreOrder(['ghost1', 'ghost2']);
    expect(q.order.map((e) => e.id).toList(), before);
    check(q, where: 'ghost restore');
  });

  test('engine staleness tracks every order change exactly once', () {
    final q = PlayQueue(source: [t(0), t(1)]);
    expect(q.engineIsStale, isTrue, reason: 'a new queue is unsynced');
    q.markEngineSynced();
    expect(q.engineIsStale, isFalse);

    q.remove('ghost');
    expect(q.engineIsStale, isFalse, reason: 'a refused edit is not an order change');

    q.remove('t0');
    expect(q.engineIsStale, isTrue);
    q.markEngineSynced();

    q.next(wrap: false);
    expect(q.engineIsStale, isFalse, reason: 'moving the needle is not reordering');
  });

  test('a duplicated selection cannot enter the queue twice', () {
    final q = PlayQueue(source: [t(0), t(1)]);
    q.promoteToNext([t(5), t(5), t(6)]);
    check(q, where: 'promoteToNext with a repeated id');
  });

  test('a duplicated source list cannot survive replaceSource', () {
    final q = PlayQueue(source: [t(0)]);
    q.replaceSource([t(3), t(3), t(4), t(4)]);
    check(q, where: 'replaceSource with repeated ids');
  });

  test('shuffle on/off returns the same current track', () {
    for (var seed = 0; seed < 20; seed++) {
      final rng = Random(seed);
      final q = PlayQueue(
        source: [for (var i = 0; i < 30; i++) t(i)],
        random: rng,
      );
      for (var i = 0; i < seed % 7; i++) {
        q.next(wrap: false);
      }
      final playing = q.current!.id;
      q.setShuffle(true);
      expect(q.current!.id, playing, reason: 'seed $seed: shuffle moved the current track');
      check(q, where: 'seed $seed shuffled');
      q.setShuffle(false);
      expect(q.current!.id, playing, reason: 'seed $seed: unshuffle moved the current track');
      check(q, where: 'seed $seed unshuffled');
    }
  });
}
