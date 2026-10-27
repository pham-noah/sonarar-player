library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/library/variant_playlist.dart';

Track _t(String id, String title, {String? of, String? tag}) => Track(
      id: id,
      title: title,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
      variantOf: of,
      variantTag: tag,
    );

List<Track> _lib() => [
      _t('lonely', 'A Song With No Second Recording'),
      _t('other', 'Another Lonely Song'),
      _t('mask', 'Beneath the Mask -instrumental version'),
      _t('mask-rain', 'Beneath the Mask -rain', of: 'mask', tag: 'rain'),
      _t('mask-rain-inst', 'Beneath the Mask -rain, instrumental',
          of: 'mask', tag: 'rain'),
      _t('life', 'Life Will Change'),
      _t('life-inst', 'Life Will Change -instrumental', of: 'life', tag: 'instrumental'),
    ];

void main() {
  group('what belongs in the list', () {
    test('only tracks that HAVE a sibling', () {
      final ids = variantRecordings(_lib()).map((t) => t.id).toList();
      expect(ids, isNot(contains('lonely')));
      expect(ids, isNot(contains('other')));
    });

    test('every member of a family, base included', () {
      final ids = variantRecordings(_lib()).map((t) => t.id).toSet();
      expect(ids, containsAll(['mask', 'mask-rain', 'mask-rain-inst']));
    });

    test('families stay TOGETHER, with the base first', () {
      final ids = variantRecordings(_lib()).map((t) => t.id).toList();
      final maskAt = ids.indexOf('mask');
      expect(ids[maskAt + 1], anyOf('mask-rain', 'mask-rain-inst'));
      expect(ids[maskAt + 2], anyOf('mask-rain', 'mask-rain-inst'));

      final lifeAt = ids.indexOf('life');
      expect(lifeAt, greaterThan(maskAt + 2));
    });

    test('a family of ONE is not a family', () {
      expect(variantFamilyCount(_lib()), 2);
    });
  });

  group('the playlist', () {
    test('is null when nothing has a second recording', () {
      expect(variantsPlaylist([_t('a', 'A'), _t('b', 'B')]), isNull);
    });

    test('carries every recording of every family', () {
      final p = variantsPlaylist(_lib())!;
      expect(p.id, kVariantsId);
      expect(p.name, 'Variants');
      expect(p.trackIds.length, 5);
    });

    test('the id is reserved, so a user playlist cannot collide with it', () {
      expect(kVariantsId.startsWith('__'), isTrue);
    });

    test('the blurb states the count that matters', () {
      expect(variantsBlurb(5, 2), '5 recordings across 2 songs.');
      expect(variantsBlurb(1, 1), '1 recording across 1 song.');
      expect(variantsBlurb(0, 0), contains('No track'));
    });
  });
}
