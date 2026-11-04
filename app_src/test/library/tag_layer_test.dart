library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/tag_layer.dart';
import 'package:sonarar/library/tag_overrides.dart';
import 'package:sonarar/library/track.dart';

Track _t(String id, {String title = 'Title', String artist = 'Artist', String album = 'Album'}) =>
    Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: const Duration(seconds: 120),
      file: 'music/$id.m4a',
      cover: '',
      gainDb: 0,
    );

void main() {
  group('the tag layer', () {
    test('starts as the library it was given', () {
      final layer = TagLayer(raw: [_t('a'), _t('b')]);

      expect(layer.library.map((t) => t.id), ['a', 'b']);
      expect(layer.library.first.title, 'Title');
      expect(layer.overrides.isEmpty, isTrue);
    });

    test('an override retitles the copy and leaves the raw library alone', () {
      final layer = TagLayer(raw: [_t('a')]);

      layer.override('a', TagField.title, 'Retitled');

      expect(layer.library.single.title, 'Retitled');
      expect(layer.raw.single.title, 'Title',
          reason: 'the disk said Title; the override is the user\'s opinion on top');
    });

    test('clearing one field restores that field only', () {
      final layer = TagLayer(raw: [_t('a')]);
      layer.override('a', TagField.title, 'Retitled');
      layer.override('a', TagField.artist, 'Retitled Artist');

      layer.clear('a', TagField.title);

      expect(layer.library.single.title, 'Title');
      expect(layer.library.single.artist, 'Retitled Artist');
    });

    test('clearing everything goes back to the disk', () {
      final layer = TagLayer(raw: [_t('a'), _t('b')]);
      layer.override('a', TagField.title, 'One');
      layer.override('b', TagField.album, 'Two');

      layer.clearAll();

      expect(layer.library.map((t) => t.title), ['Title', 'Title']);
      expect(layer.library.map((t) => t.album), ['Album', 'Album']);
      expect(layer.overrides.isEmpty, isTrue);
    });

    test('a NEW library keeps the overrides that still apply', () {
      final layer = TagLayer(raw: [_t('a')]);
      layer.override('a', TagField.title, 'Retitled');

      layer.replaceRaw([_t('a'), _t('b')]);

      expect(layer.library, hasLength(2));
      expect(layer.library.first.title, 'Retitled',
          reason: 'a rescan must not silently undo what the user retitled');
      expect(layer.library.last.title, 'Title');
    });

    test('an override for a track that is gone applies to nothing, and does not throw',
        () {
      final layer = TagLayer(raw: [_t('a')]);
      layer.override('gone', TagField.title, 'Nowhere');

      expect(layer.library, hasLength(1));
      expect(layer.library.single.title, 'Title');
    });

    test('the whole override set can be replaced at once, as boot does', () {
      final layer = TagLayer(raw: [_t('a')]);
      final overrides = TagOverrides()..set('a', TagField.title, 'From Disk');

      layer.replaceOverrides(overrides);

      expect(layer.library.single.title, 'From Disk');
      expect(layer.overrides.isEmpty, isFalse);
    });

    test('an empty library stays empty rather than inventing a track', () {
      final layer = TagLayer();
      layer.override('a', TagField.title, 'Retitled');

      expect(layer.raw, isEmpty);
      expect(layer.library, isEmpty);
    });

    test('the library it hands out cannot be edited from outside', () {
      final layer = TagLayer(raw: [_t('a')]);

      expect(() => layer.library.add(_t('b')), throwsUnsupportedError);
      expect(() {
        layer.library[0] = _t('b');
      }, throwsUnsupportedError);
    });
  });
}
