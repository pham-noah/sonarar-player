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
  test('unshuffling restores the SOURCE order, not a new shuffle', () {
    final source = _lib(12);
    final q = PlayQueue(source: source);

    final original = q.order.map((t) => t.id).toList();

    q.setShuffle(true);
    expect(q.order.map((t) => t.id).toList(), isNot(original),
        reason: 'shuffle must actually shuffle');

    q.setShuffle(false);

    expect(q.order.map((t) => t.id).toList(), original,
        reason: 'unshuffling must give back the plain order, not a permutation');
  });

  test('unshuffling keeps the SAME track current', () {
    final q = PlayQueue(source: _lib(12));

    q.setShuffle(true);

    q.next(wrap: true);
    q.next(wrap: true);
    final playing = q.current!.id;

    q.setShuffle(false);

    expect(q.current!.id, playing,
        reason: 'a mode switch must never change the song');

    expect(q.order[q.index].id, playing);
  });

  test('after unshuffling, the upcoming list is the source order after it', () {
    final q = PlayQueue(source: _lib(10));

    q.setShuffle(true);
    q.next(wrap: true);
    final playing = q.current!.id;

    q.setShuffle(false);

    final plain = _lib(10).map((t) => t.id).toList();
    final at = plain.indexOf(playing);
    expect(
      q.upcoming.map((t) => t.id).toList(),
      plain.sublist(at + 1),
      reason: 'unshuffled, UP NEXT must be the plain order after the current',
    );
  });

  test('shuffling off is idempotent', () {
    final q = PlayQueue(source: _lib(8));
    q.setShuffle(true);
    q.setShuffle(false);
    final once = q.order.map((t) => t.id).toList();
    q.setShuffle(false);
    expect(q.order.map((t) => t.id).toList(), once);
  });
}
