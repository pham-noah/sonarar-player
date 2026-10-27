library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

List<Track> _lib(int n) => List.generate(n, (i) => _t('t$i'));

void main() {
  test('advancing does NOT reorder what is still coming', () {
    final q = PlayQueue(source: _lib(40), shuffle: true);

    final before = q.upcoming.map((t) => t.id).toList();
    expect(before.length, 39);

    q.next(wrap: true);

    final after = q.upcoming.map((t) => t.id).toList();

    expect(after, before.sublist(1),
        reason: 'the upcoming queue must survive a skip unchanged');
  });

  test('a shuffled pass visits every track exactly once', () {
    final q = PlayQueue(source: _lib(20), shuffle: true);

    final seen = <String>{q.current!.id};
    for (var i = 0; i < 19; i++) {
      q.next(wrap: false);
      seen.add(q.current!.id);
    }

    expect(seen.length, 20,
        reason: 'a pass is a permutation: no track twice, none skipped');
  });

  test('the order is stable across several skips', () {
    final q = PlayQueue(source: _lib(30), shuffle: true);

    final first = q.upcoming.map((t) => t.id).toList();

    q.next(wrap: true);
    q.next(wrap: true);
    q.next(wrap: true);

    expect(q.upcoming.map((t) => t.id).toList(), first.sublist(3));
  });

  test('a wrap continues rather than stopping', () {
    final q = PlayQueue(source: _lib(6), shuffle: true);

    for (var i = 0; i < 5; i++) {
      q.next(wrap: false);
    }
    expect(q.next(wrap: true), isNotNull,
        reason: 'a wrap continues rather than stopping');
  });

  test('switching shuffle on does not restart the current track', () {
    final q = PlayQueue(source: _lib(10));
    final cur = q.current!.id;

    q.setShuffle(true);

    expect(q.current!.id, cur, reason: 'changing mode must not change the song');
  });
}
