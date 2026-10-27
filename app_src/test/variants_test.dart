library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/library/variants.dart';
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
  group('variant grouping', () {
    test('a track with no variant_of is its own group', () {
      final a = _t('a');
      expect(variantGroupKey(a), 'a');
      expect(variantsOf(a, [a]), isEmpty);
    });

    test('a variant and its parent share a group, and find each other', () {
      final album = _t('beneath');
      final rain = _t('beneath-rain', of: 'beneath', tag: 'rain');
      final lib = [album, rain];

      expect(variantGroupKey(rain), 'beneath');
      expect(variantsOf(album, lib).map((t) => t.id), ['beneath-rain']);
      expect(variantsOf(rain, lib).map((t) => t.id), ['beneath']);
    });

    test('a track is never its own variant', () {
      final album = _t('beneath');
      final rain = _t('beneath-rain', of: 'beneath', tag: 'rain');
      expect(variantsOf(album, [album, rain]).any((t) => t.id == 'beneath'), isFalse);
    });

    test('an UNKNOWN tag is dropped, so no swap is offered that cannot be named', () {
      final album = _t('beneath');

      final odd = _t('beneath-x', of: 'beneath', tag: 'rainn');
      expect(variantsOf(album, [album, odd]), isEmpty);
    });

    test('variants are offered in kVariantTags order, not library order', () {
      final album = _t('beneath');
      final long = _t('beneath-long', of: 'beneath', tag: 'long');
      final ac = _t('beneath-acoustic', of: 'beneath', tag: 'acoustic');
      final inst = _t('beneath-inst', of: 'beneath', tag: 'instrumental');

      final lib = [album, long, ac, inst];

      expect(
        variantsOf(album, lib).map((t) => t.variantTag),
        ['acoustic', 'instrumental', 'long'],
      );
    });

    test('a title collision does NOT group two unrelated recordings', () {
      final jp = _t('jp', title: '全ての人の魂の詩');
      final cover = _t('cover', title: '全ての人の魂の詩', tag: 'arrange');

      expect(variantGroupKey(cover), 'cover');
      expect(variantsOf(jp, [jp, cover]), isEmpty);
    });

    test('rain is the only variant the app chooses for itself, and only in rain', () {
      expect(preferredVariantFor(raining: true, snowing: false), 'rain');
      expect(preferredVariantFor(raining: false, snowing: true), isNull);
      expect(preferredVariantFor(raining: false, snowing: false), isNull);
    });

    test('the label is the tag the manifest uses, uppercased', () {
      expect(variantLabel('rain'), 'RAIN');
      expect(variantLabel('instrumental'), 'INSTRUMENTAL');
    });

    test('every tag in the fixed set is recognised', () {
      for (final tag in kVariantTags) {
        expect(isKnownVariantTag(tag), isTrue, reason: tag);
      }
    });
  });

  group('short and long are DERIVED from duration', () {
    Track withLen(String id, int seconds, {String? of, String? tag}) => Track(
          id: id,
          title: 'T $id',
          artist: 'A',
          album: 'Al',
          duration: Duration(seconds: seconds),
          file: '$id.opus',
          cover: '',
          gainDb: null,
          variantOf: of,
          variantTag: tag,
        );

    test('a track can carry TWO tags: the one it declares and the one it measures', () {
      final full = withLen('full', 167);
      final short = withLen('short', 92, of: 'full', tag: 'instrumental');
      final lib = [full, short];

      final tags = effectiveVariantTags(short, lib);
      expect(tags, contains('instrumental'), reason: 'the declared tag');
      expect(tags, contains('short'), reason: 'the measured one');
      expect(carriesVariantTag(short, 'short', lib), isTrue);
    });

    test('the long side of the same pair is the full-length cut', () {
      final full = withLen('full', 167);
      final short = withLen('short', 92, of: 'full', tag: 'instrumental');
      final lib = [full, short];
      expect(carriesVariantTag(full, 'long', lib), isTrue);
    });

    test('siblings of similar length are neither short nor long', () {
      final a = withLen('a', 399);
      final b = withLen('b', 399, of: 'a', tag: 'instrumental');
      final lib = [a, b];
      expect(carriesVariantTag(a, 'short', lib), isFalse);
      expect(carriesVariantTag(b, 'short', lib), isFalse);
      expect(carriesVariantTag(a, 'long', lib), isFalse);
    });

    test('a track with no siblings is neither', () {
      final lone = withLen('lone', 200);
      expect(effectiveVariantTags(lone, [lone]), isEmpty);
      expect(carriesVariantTag(lone, 'short', [lone]), isFalse);
    });

    test('the declared tag survives when nothing can be derived', () {
      final a = withLen('a', 200);
      final b = withLen('b', 200, of: 'a', tag: 'rain');
      expect(effectiveVariantTags(b, [a, b]), {'rain'});
    });
  });

  group('PlayQueue.replaceCurrent', () {
    test('swaps the current track and keeps the index', () {
      final a = _t('a');
      final b = _t('b');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a, b], random: Random(1));

      expect(q.order[q.index].id, 'a');
      expect(q.replaceCurrent(rain), isTrue);
      expect(q.order[q.index].id, 'a-rain');

      expect(q.index, 0);
    });

    test('the swap SURVIVES a wrap — the source list is updated too', () {
      final a = _t('a');
      final b = _t('b');
      final rain = _t('a-rain', of: 'a', tag: 'rain');
      final q = PlayQueue(source: [a, b], random: Random(1));

      q.replaceCurrent(rain);

      q.next(wrap: true);
      q.next(wrap: true);

      final ids = q.order.map((t) => t.id).toList();
      expect(ids, contains('a-rain'), reason: 'the swapped recording is still queued');
      expect(ids, isNot(contains('a')), reason: 'and the original is not back');
    });

    test('an empty queue refuses rather than throwing', () {
      final q = PlayQueue(source: const [], random: Random(1));
      expect(q.replaceCurrent(_t('x')), isFalse);
    });
  });
}
