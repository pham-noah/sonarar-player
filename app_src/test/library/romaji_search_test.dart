library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';

Track _jp({String? romaji}) => Track(
      id: 'jp1',
      title: '10年前の記憶 -対峙',
      artist: 'ATLUS Sound Team',
      album: 'Persona 3 Reload',
      duration: const Duration(minutes: 3),
      file: 'ATLUS Sound Team/Persona 3 Reload/10年前の記憶 -対峙.opus',
      cover: '',
      gainDb: -4.2,
      romaji: romaji,
    );

void main() {
  group('a reading makes a Japanese title findable', () {
    test('WITHOUT one, the romaji does not match', () {
      final t = _jp();
      expect(t.matches('kioku'), isFalse);
      expect(t.matches('10nenmae'), isFalse);
    });

    test('WITH one, the romaji matches', () {
      final t = _jp(romaji: '10nenmaenokiokutaiji atlussoundteam persona3reload');
      expect(t.matches('kioku'), isTrue);
      expect(t.matches('10nenmae'), isTrue);
      expect(t.matches('taiji'), isTrue);
    });

    test('a reading is matched in the middle of a word too', () {
      final t = _jp(romaji: 'konofushiginakankaku atlussoundteam persona3reload');
      expect(t.matches('fushigi'), isTrue);
      expect(t.matches('nakan'), isTrue);
    });

    test('multiple terms all have to land, across scripts', () {
      final t = _jp(romaji: '10nenmaenokiokutaiji atlussoundteam persona3reload');
      expect(t.matches('kioku reload'), isTrue);
      expect(t.matches('kioku nirvana'), isFalse);
    });

    test('the reading does not REPLACE matching on the real titles', () {
      final t = _jp(romaji: '10nenmaenokiokutaiji atlussoundteam persona3reload');
      expect(t.matches('ATLUS'), isTrue);
      expect(t.matches('Persona 3 Reload'), isTrue);
      expect(t.matches('記憶'), isTrue);
    });

    test('case does not matter on either side', () {
      final t = _jp(romaji: '10nenmaenokiokutaiji atlussoundteam persona3reload');
      expect(t.matches('KIOKU'), isTrue);
      expect(t.matches('KiOkU'), isTrue);
    });
  });

  group('a track with no reading is unchanged', () {
    test('the latin case still searches exactly as before', () {
      final t = Track(
        id: 'x',
        title: 'Brand New Days',
        artist: 'ATLUS Sound Team',
        album: 'P3R',
        duration: const Duration(minutes: 3),
        file: 'a/b/c.opus',
        cover: '',
        gainDb: null,
      );
      expect(t.romaji, isNull);
      expect(t.matches('brand new'), isTrue);
      expect(t.matches('atlus'), isTrue);
    });
  });

  group('parsing the manifest', () {
    test('a romaji field is read', () {
      final t = Track.fromJson({
        'id': 'a',
        'title': 'やすらぎ',
        'artist': 'ATLUS Sound Team',
        'album': 'Persona 3 Reload',
        'duration_s': 120,
        'file': 'a/b/c.opus',
        'cover': '',
        'gain_db': -3.0,
        'romaji': 'yasuragi atlussoundteam persona3reload',
      });
      expect(t.romaji, isNotNull);
      expect(t.matches('yasuragi'), isTrue);
    });

    test('an ABSENT field is null, not an error', () {
      final t = Track.fromJson({
        'id': 'a',
        'title': 'Brand New Days',
        'artist': 'ATLUS',
        'album': 'P3R',
        'duration_s': 120,
        'file': 'a/b/c.opus',
        'cover': '',
        'gain_db': null,
      });
      expect(t.romaji, isNull);
      expect(t.matches('brand new'), isTrue);
    });

    test('a BLANK field is treated as absent', () {
      final t = Track.fromJson({
        'id': 'a',
        'title': 'X',
        'artist': 'Y',
        'album': 'Z',
        'duration_s': 120,
        'file': 'a/b/c.opus',
        'cover': '',
        'gain_db': null,
        'romaji': '   ',
      });
      expect(t.romaji, isNull);
    });

    test('a whole manifest with a mixed library parses', () {
      final json = jsonEncode({
        'tracks': [
          {
            'id': 'a',
            'title': 'やすらぎ',
            'artist': 'ATLUS',
            'album': 'P3R',
            'duration_s': 100,
            'file': 'x',
            'cover': '',
            'gain_db': null,
            'romaji': 'yasuragi atlus p3r',
          },
          {
            'id': 'b',
            'title': 'Brand New Days',
            'artist': 'ATLUS',
            'album': 'P3R',
            'duration_s': 100,
            'file': 'y',
            'cover': '',
            'gain_db': null,
          },
        ],
      });
      final tracks = Track.listFromManifest(json);
      expect(tracks.length, 2);
      expect(tracks[0].matches('yasuragi'), isTrue);
      expect(tracks[1].romaji, isNull);
      expect(tracks[1].matches('brand'), isTrue);
    });
  });

  group('a metadata correction keeps the reading', () {
    test('correcting a title does not lose findability', () {
      final t = _jp(romaji: '10nenmaenokiokutaiji atlussoundteam persona3reload');
      final fixed = t.withMetadata(title: 'Ten Years Ago - Confrontation');
      expect(fixed.romaji, isNotNull);
      expect(fixed.matches('kioku'), isTrue);
      expect(fixed.matches('confrontation'), isTrue);
    });
  });
}
