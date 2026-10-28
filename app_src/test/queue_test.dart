library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';

Track _t(String id, {String? artist, Duration? dur}) => Track(
      id: id,
      title: 'Track $id',
      artist: artist ?? 'Artist',
      album: 'Album',
      duration: dur ?? const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

List<Track> _many(int n) => List.generate(n, (i) => _t('t$i'));

void main() {
  group('skip classification', () {
    const dur = Duration(minutes: 3);

    test('skipping inside the window is a no', () {
      expect(
        classifyOutcome(
          positionWhenStopped: const Duration(seconds: 4),
          trackDuration: dur,
        ),
        PlayOutcome.skippedEarly,
      );
    });

    test('the threshold itself counts as a late skip, not an early one', () {
      expect(
        classifyOutcome(
          positionWhenStopped: kSkipThreshold,
          trackDuration: dur,
        ),
        PlayOutcome.skippedLate,
      );
    });

    test('skipping well in is a late skip — the song was fine', () {
      expect(
        classifyOutcome(
          positionWhenStopped: const Duration(minutes: 2),
          trackDuration: dur,
        ),
        PlayOutcome.skippedLate,
      );
    });

    test('playing to the end is a yes', () {
      expect(
        classifyOutcome(
          positionWhenStopped: dur,
          trackDuration: dur,
        ),
        PlayOutcome.completed,
      );
    });

    test('near the end still counts as completed', () {
      expect(
        classifyOutcome(
          positionWhenStopped: dur - kFinishTolerance,
          trackDuration: dur,
        ),
        PlayOutcome.completed,
      );
    });

    test('a zero-length track does not divide by anything or crash', () {
      expect(
        classifyOutcome(
          positionWhenStopped: Duration.zero,
          trackDuration: Duration.zero,
        ),
        PlayOutcome.skippedEarly,
      );
    });

    test('overshooting the end is still completed, not an error', () {
      expect(
        classifyOutcome(
          positionWhenStopped: const Duration(minutes: 4),
          trackDuration: dur,
        ),
        PlayOutcome.completed,
      );
    });

    test('a LONGER window reclassifies a late skip as early', () {
      const at30s = Duration(seconds: 30);
      expect(
        classifyOutcome(positionWhenStopped: at30s, trackDuration: dur),
        PlayOutcome.skippedLate,
      );

      expect(
        classifyOutcome(
          positionWhenStopped: at30s,
          trackDuration: dur,
          skipThreshold: const Duration(seconds: 45),
        ),
        PlayOutcome.skippedEarly,
      );
    });

    test('a SHORTER window reclassifies an early skip as late', () {
      const at12s = Duration(seconds: 12);
      expect(
        classifyOutcome(positionWhenStopped: at12s, trackDuration: dur),
        PlayOutcome.skippedLate,
      );

      expect(
        classifyOutcome(
          positionWhenStopped: at12s,
          trackDuration: dur,
          skipThreshold: const Duration(seconds: 5),
        ),
        PlayOutcome.skippedLate,
      );

      expect(
        classifyOutcome(
          positionWhenStopped: const Duration(seconds: 3),
          trackDuration: dur,
          skipThreshold: const Duration(seconds: 5),
        ),
        PlayOutcome.skippedEarly,
      );
    });

    test('the window cannot turn a COMPLETED track into a skip', () {
      expect(
        classifyOutcome(
          positionWhenStopped: const Duration(seconds: 200),
          trackDuration: dur,
          skipThreshold: const Duration(minutes: 30),
        ),
        PlayOutcome.completed,
      );
    });
  });

  group('queue basics', () {
    test('starts at the first track', () {
      final q = PlayQueue(source: _many(5));
      expect(q.length, 5);
      expect(q.current!.id, 't0');
      expect(q.index, 0);
    });

    test('next advances and wraps', () {
      final q = PlayQueue(source: _many(3));
      expect(q.next(wrap: true)!.id, 't1');
      expect(q.next(wrap: true)!.id, 't2');
      expect(q.next(wrap: true)!.id, 't0', reason: 'should wrap');
    });

    test('previous is the inverse of next', () {
      final q = PlayQueue(source: _many(4));
      final start = q.current!.id;
      q.next(wrap: true);
      expect(q.previous()!.id, start);
    });

    test('an empty queue is a state, not a crash', () {
      final q = PlayQueue(source: const []);
      expect(q.isEmpty, isTrue);
      expect(q.current, isNull);
      expect(q.next(wrap: true), isNull);
      expect(q.previous(), isNull);
      expect(q.upcoming, isEmpty);
    });

    test('upcoming lists everything after the current track', () {
      final q = PlayQueue(source: _many(5));
      expect(q.upcoming.map((t) => t.id), ['t1', 't2', 't3', 't4']);
      q.next(wrap: true);
      expect(q.upcoming.map((t) => t.id), ['t2', 't3', 't4']);
    });

    test('jumpTo finds a track, and refuses an unknown id', () {
      final q = PlayQueue(source: _many(5));
      expect(q.jumpTo('t3'), isTrue);
      expect(q.current!.id, 't3');
      expect(q.jumpTo('nope'), isFalse);
      expect(q.current!.id, 't3', reason: 'a failed jump must not move');
    });
  });

  group('shuffle does not cluster', () {
    test('a shuffled queue holds every track exactly once', () {
      final q = PlayQueue(source: _many(40), random: Random(7), shuffle: true);
      final ids = q.order.map((t) => t.id).toSet();
      expect(ids.length, 40, reason: 'no track lost or duplicated');
    });

    test('tracks played recently are pushed to the back', () {
      final q = PlayQueue(source: _many(40), random: Random(1), shuffle: true);

      final justPlayed = <String>[];
      for (var i = 0; i < kNoRepeatWindow; i++) {
        justPlayed.add(q.current!.id);
        q.next(wrap: true);
      }

      q.setShuffle(false);
      q.setShuffle(true);

      final firstFew = q.order.take(8).map((t) => t.id).toList();
      final overlap = firstFew.where(justPlayed.contains).length;
      expect(overlap, lessThanOrEqualTo(2),
          reason: 'recent tracks leaked into the top of the shuffle: $firstFew');
    });

    test('no immediate repeat across a long run', () {
      final q = PlayQueue(source: _many(30), random: Random(3), shuffle: true);
      String? last;
      for (var i = 0; i < 60; i++) {
        final cur = q.current!.id;
        expect(cur, isNot(last), reason: 'repeated $cur back to back');
        last = cur;
        q.next(wrap: true);
      }
    });

    test('a tiny library degrades gracefully instead of deadlocking', () {
      final q = PlayQueue(source: _many(3), random: Random(5), shuffle: true);
      expect(q.length, 3);
      for (var i = 0; i < 12; i++) {
        expect(q.current, isNotNull);
        q.next(wrap: true);
      }
    });

    test('switching shuffle does not restart the current song', () {
      final q = PlayQueue(source: _many(20), random: Random(9));
      q.next(wrap: true);
      q.next(wrap: true);
      final playing = q.current!.id;
      q.setShuffle(true);
      expect(q.current!.id, playing,
          reason: 'changing shuffle must never change what is playing');
      q.setShuffle(false);
      expect(q.current!.id, playing);
    });

    test('shuffling a single track is not a crash', () {
      final q = PlayQueue(source: _many(1), shuffle: true);
      expect(q.length, 1);
      expect(q.next(wrap: true)!.id, 't0');
    });
  });

  group('editing the queue', () {
    test('playNext inserts directly after the current track', () {
      final q = PlayQueue(source: _many(5));
      q.playNext(_t('extra'));
      expect(q.upcoming.first.id, 'extra');
      expect(q.length, 6);
    });

    test('move reorders without changing what is playing', () {
      final q = PlayQueue(source: _many(5));
      q.jumpTo('t2');
      final playing = q.current!.id;
      expect(q.move(4, 0), isTrue);
      expect(q.order.first.id, 't4');
      expect(q.current!.id, playing,
          reason: 'reordering the list must not change the current track');
    });

    test('move rejects out-of-range positions', () {
      final q = PlayQueue(source: _many(3));
      expect(q.move(-1, 0), isFalse);
      expect(q.move(0, 99), isFalse);
      expect(q.length, 3);
    });

    test('remove drops a track from the queue and the source', () {
      final q = PlayQueue(source: _many(5));
      expect(q.remove('t2'), isTrue);
      expect(q.length, 4);
      expect(q.order.any((t) => t.id == 't2'), isFalse);

      q.setShuffle(true);
      expect(q.order.any((t) => t.id == 't2'), isFalse);
    });

    test('removing the current track keeps the queue usable', () {
      final q = PlayQueue(source: _many(5));
      q.jumpTo('t2');
      q.remove('t2');
      expect(q.current, isNotNull);
      expect(q.current!.id, 't3');
      expect(q.index, lessThan(q.length));
    });

    test('removing a track before the current one keeps the position sane', () {
      final q = PlayQueue(source: _many(5));
      q.jumpTo('t3');
      q.remove('t0');
      expect(q.current!.id, 't3', reason: 'current track must not shift under us');
      expect(q.index, lessThan(q.length));
    });

    test('removing a track that is not queued returns false', () {
      final q = PlayQueue(source: _many(3));
      expect(q.remove('ghost'), isFalse);
      expect(q.length, 3);
    });

    test('removing the last track leaves an empty queue, not a crash', () {
      final q = PlayQueue(source: _many(1));
      expect(q.remove('t0'), isTrue);
      expect(q.isEmpty, isTrue);
      expect(q.current, isNull);
      expect(q.next(wrap: true), isNull);
    });
  });

  group('replacing the library', () {
    test('a new source resets to the start', () {
      final q = PlayQueue(source: _many(10));
      q.jumpTo('t5');
      q.replaceSource(_many(4));
      expect(q.length, 4);
      expect(q.current!.id, 't0');
    });
  });

  group('the three insert policies', () {
    test('append goes to the END and refuses a track already queued', () {
      final q = PlayQueue(source: _many(4));
      expect(q.append(_t('new')), isTrue);
      expect(q.order.last.id, 'new');
      expect(q.append(_t('new')), isFalse,
          reason: 'a repeated append should not stack a duplicate');
      expect(q.order.where((t) => t.id == 'new').length, 1);
    });

    test('playNext goes after the current one, MOVING if already queued', () {
      final q = PlayQueue(source: _many(6));
      q.jumpTo('t0');
      q.playNext(_t('fresh'));
      expect(q.order.take(2).map((t) => t.id), ['t0', 'fresh']);

      q.jumpTo('t2');
      expect(q.jumpTo('t2'), isTrue);
      q.playNext(_t('t5'));
      final ids = q.order.map((t) => t.id).toList();
      expect(ids[q.index + 1], 't5',
          reason: 'playNext puts it immediately after the current track');
      expect(ids.where((id) => id == 't5').length, 1,
          reason: 'the same recording twice is a pair impossible to tell apart');
      expect(q.length, 7, reason: 'a move is not an insert — only the earlier insert grew it');
    });
    test('promoteToNext moves every track given, in the order given', () {
      final q = PlayQueue(source: _many(10));
      q.jumpTo('t0');
      q.promoteToNext([_t('t7'), _t('t2')]);
      expect(q.order.take(3).map((t) => t.id), ['t0', 't7', 't2']);

      expect(q.order.where((t) => t.id == 't7').length, 1);
      expect(q.order.where((t) => t.id == 't2').length, 1);
      expect(q.length, 10, reason: 'a move is not an insert');
    });

    test('an empty insert is a no-op on every policy', () {
      final q = PlayQueue(source: _many(4));
      final before = q.orderVersion;
      q.playNext(_t('nonexistent-insert'));
      q.promoteToNext(const []);
      expect(q.orderVersion, before + 1);
      expect(q.length, 5);
    });

    test('the version bumps once per insert, not once per track', () {
      final q = PlayQueue(source: _many(4));
      final before = q.orderVersion;
      q.promoteToNext([_t('a'), _t('b'), _t('c')]);
      expect(q.orderVersion, before + 1,
          reason: 'one insert is one change to the order, and a burst of bumps '
              'would thrash the engine');
    });
  });

  group('next() demands to be told whether to wrap', () {
    test('wrap off returns null at the end rather than restarting the pass', () {
      final q = PlayQueue(source: _many(3));
      q.next(wrap: true);
      q.next(wrap: true);

      expect(q.next(wrap: false), isNull);
      expect(q.current!.id, 't2', reason: 'the queue stayed put');
    });

    test('wrap on starts a new pass', () {
      final q = PlayQueue(source: _many(3));
      q.next(wrap: true);
      q.next(wrap: true);
      expect(q.next(wrap: true)!.id, 't0');
    });

    test('an empty queue ends rather than crashes', () {
      final q = PlayQueue(source: const <Track>[]);
      expect(q.next(wrap: false), isNull);
      expect(q.next(wrap: true), isNull);
    });
  });

  group('a move must not move what is playing', () {
    test('playNext on a track ABOVE the current one keeps the same track', () {
      final q = PlayQueue(source: _many(5));
      q.jumpTo('t3');

      q.playNext(_t('t1'));

      expect(q.current!.id, 't3');
      expect(q.order.map((t) => t.id).toList(), ['t0', 't2', 't3', 't1', 't4']);
      expect(q.index, 2,
          reason: 'the index follows the track, not the position it used to hold');
    });

    test('promoteToNext spanning both sides keeps the same track', () {
      final q = PlayQueue(source: _many(6));
      q.jumpTo('t4');

      q.promoteToNext([_t('t1'), _t('t9')]);

      expect(q.current!.id, 't4');
      expect(q.upcoming.take(2).map((t) => t.id), ['t1', 't9']);
    });

    test('promoting the playing track leaves it alone and moves the rest', () {
      final q = PlayQueue(source: _many(4));
      q.jumpTo('t2');

      q.promoteToNext([_t('t2'), _t('t0')]);

      expect(q.current!.id, 't2');
      expect(q.upcoming.first.id, 't0');
      expect(q.order.where((t) => t.id == 't2').length, 1);
      expect(q.length, 4, reason: 'nothing was inserted, only reordered');
    });

    test('repeated moves never strand the index past the end', () {
      final q = PlayQueue(source: _many(6));
      q.jumpTo('t5');
      for (final id in ['t0', 't1', 't2', 't3', 't4']) {
        q.playNext(_t(id));
        expect(q.index, lessThan(q.length));
      }
      expect(q.current!.id, 't5');
    });
  });
}
