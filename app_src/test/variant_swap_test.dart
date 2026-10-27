library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';

Track _t(String id, {String? of, String? tag, String title = 'Beneath the Mask'}) =>
    Track(
      id: id,
      title: title,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '$id.jpg',
      gainDb: null,
      variantOf: of,
      variantTag: tag,
    );

void main() {
  group('the queue keeps the swap in the SAME SLOT', () {
    test('the index does not move, so the running order is unchanged', () {
      final a = _t('a');
      final b = _t('b');
      final c = _t('c');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a, b, c]);
      q.jumpTo('b');

      final before = q.index;
      q.replaceCurrent(rain);

      expect(q.index, before, reason: 'the slot is preserved');
      expect(q.order[q.index].id, 'a-rain');
      expect(q.order.map((t) => t.id), ['a', 'a-rain', 'c']);
    });

    test('the swap survives a pass boundary — it is not undone at the wrap', () {
      final a = _t('a');
      final b = _t('b');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a, b]);
      q.jumpTo('a');
      q.replaceCurrent(rain);

      q.next(wrap: true);
      q.next(wrap: true);

      final ids = q.order.map((t) => t.id).toList();
      expect(ids, contains('a-rain'));
      expect(ids, isNot(contains('a')), reason: 'the original must not come back');
    });

    test('swapping in a track already queued does not duplicate it', () {
      final a = _t('a');
      final b = _t('b');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a, b, rain]);
      q.jumpTo('a');

      expect(q.replaceCurrent(rain), isTrue);
      final ids = q.order.map((t) => t.id).toList();
      expect(ids.where((id) => id == 'a-rain').length, 1);
    });
  });

  group('the swap the engine is asked to perform', () {
    test('a variant is the same music, so the position is the thing carried', () {
      final a = _t('a');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a]);
      q.jumpTo('a');

      final moved = q.replaceCurrent(rain);
      expect(moved, isTrue);

      expect(q.order[q.index].variantOf, 'a');
    });
  });
}
