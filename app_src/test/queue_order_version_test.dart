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
  test('a fresh queue is stale until the engine is told', () {
    final q = PlayQueue(source: _lib(6));
    expect(q.engineIsStale, isTrue,
        reason: 'nothing has pushed this order to the engine yet');
    q.markEngineSynced();
    expect(q.engineIsStale, isFalse);
  });

  group('every order change makes the engine stale again', () {
    test('a reorder does', () {
      final q = PlayQueue(source: _lib(8))..markEngineSynced();
      q.move(1, 4);
      expect(q.engineIsStale, isTrue);
    });

    test('play next does', () {
      final q = PlayQueue(source: _lib(8))..markEngineSynced();
      q.playNext(_t('extra'));
      expect(q.engineIsStale, isTrue);
    });

    test('appending does', () {
      final q = PlayQueue(source: _lib(8))..markEngineSynced();
      expect(q.append(_t('extra')), isTrue);
      expect(q.engineIsStale, isTrue);
    });

    test('removing a track does', () {
      final q = PlayQueue(source: _lib(8))..markEngineSynced();

      expect(q.remove('t5'), isTrue);
      q.markEngineSynced();
      expect(q.remove('t6'), isTrue);
      expect(q.engineIsStale, isTrue);
    });

    test('a REPLAN does — and it keeps the current track, which is the point',
        () {
      final q = PlayQueue(source: _lib(10))..markEngineSynced();
      final before = q.current!.id;

      q.replaceSource(_lib(10).reversed.toList(), keepPlaying: true);

      expect(q.current!.id, before, reason: 'a replan keeps the song playing');
      expect(q.engineIsStale, isTrue,
          reason: '...and the ORDER changed, so the engine is now wrong');
    });

    test('a shuffle toggle does', () {
      final q = PlayQueue(source: _lib(10))..markEngineSynced();
      q.setShuffle(true);
      expect(q.engineIsStale, isTrue);
    });
  });

  test('advancing through the fixed order does NOT make it stale', () {
    final q = PlayQueue(source: _lib(6), shuffle: true)..markEngineSynced();
    q.next(wrap: true);
    expect(q.engineIsStale, isFalse,
        reason: 'a skip inside a pass leaves the order alone');
  });

  test('WRAPPING at the end of a pass marks stale', () {
    final q = PlayQueue(source: _lib(5), shuffle: true)..markEngineSynced();
    for (var i = 0; i < 4; i++) {
      q.next(wrap: false);
    }
    expect(q.engineIsStale, isFalse, reason: 'inside a pass nothing changed');

    q.next(wrap: true);
    expect(q.engineIsStale, isTrue,
        reason: 'a new pass is a new order the engine has not seen');
  });

  test('switching shuffle off restores the source order and marks stale', () {
    final q = PlayQueue(source: _lib(9))..markEngineSynced();
    q.setShuffle(true);
    q.markEngineSynced();
    q.setShuffle(false);
    expect(q.engineIsStale, isTrue);
    expect(q.order.map((t) => t.id).toList(),
        _lib(9).map((t) => t.id).toList());
  });
}
