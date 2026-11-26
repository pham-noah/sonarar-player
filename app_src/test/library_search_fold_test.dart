library;

// The search box lower-cased both sides and stopped there, so a library full of
// Björk, Sigur Rós, Motörhead and Mylène Farmer could not be searched from a
// keyboard that has no marks on it — which is every phone keyboard most of the
// time. "bjork" returned nothing. Nothing crashed and every screenshot of the
// search box looks perfect, because an empty result list is a valid screen.
//
// These tests name the artist, the query a person would actually type, and both
// directions of the match: a query typed with the mark must still find a file
// without it, or the fix only helps one kind of user.

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/search_fold.dart';
import 'package:sonarar/library/track.dart';

Track _track(String title, String artist, {String album = '', String? romaji}) =>
    Track(
      id: title,
      title: title,
      artist: artist,
      album: album,
      duration: const Duration(seconds: 214),
      file: '$title.opus',
      cover: '',
      gainDb: null,
      romaji: romaji,
    );

void main() {
  group('the marks a keyboard cannot type', () {
    final cases = <(String, String, String)>[
      ('bjork', 'Jóga', 'Björk'),
      ('joga', 'Jóga', 'Björk'),
      ('sigur ros', 'Svefn-g-englar', 'Sigur Rós'),
      ('mylene farmer', 'Désenchantée', 'Mylène Farmer'),
      ('motörhead', 'Ace of Spades', 'Motörhead'),
      ('beyonce', 'Halo', 'Beyoncé'),
      ('oya', 'Bad Moon Rising', 'Øya'),
      ('lacrimosa', 'Lacrimosa', 'Zbigniew Preisner'),
    ];

    for (final (query, title, artist) in cases) {
      test('"$query" finds $title by $artist', () {
        expect(_track(title, artist).matches(query), isTrue,
            reason: '"$query" is what someone types when they cannot type the '
                'artist name; the mark on "$artist" must not hide the track');
      });
    }

    test('a title with a sharp s is found written either way', () {
      final t = _track('Deutschland', 'Rammstein', album: 'Straße');
      for (final query in ['strasse', 'straße', 'STRASSE']) {
        expect(t.matches(query), isTrue, reason: 'query: $query');
      }
    });
  });

  group('and everything that is not a Latin mark is left alone', () {
    test('CJK still needs its own characters', () {
      final t = _track('全ての人の魂の戦い', '目黒将司');
      expect(t.matches('全ての人の魂'), isTrue);
      expect(t.matches('subete'), isFalse,
          reason: 'folding must not invent transliterations; that is what the '
              'romaji field on a track is for');
    });

    test('a romaji field is what finds a Japanese track from a Latin keyboard',
        () {
      final t = _track('全ての人の魂の戦い', '目黒将司',
          romaji: 'Subete no Hito no Tamashii no Tatakai');
      expect(t.matches('subete tamashii'), isTrue);
    });

    test('punctuation in a name survives, because it is part of the name', () {
      expect(_track('re:zero', 'MYTH & ROID').matches('re:zero'), isTrue);
      expect(_track('Svefn-g-englar', 'Sigur Rós').matches('svefn-g-englar'),
          isTrue);
      expect(foldForLibrarySearch('track_01.opus'), 'track_01.opus',
          reason: 'the YouTube search folding strips punctuation; a library '
              'search must not, or a hyphen makes a track unfindable');
    });

    test('full-width Latin from an IME is the same word', () {
      expect(foldForLibrarySearch('ＢＪＯＲＫ'), 'bjork');
      expect(_track('Halo', 'Beyoncé').matches('ｂｅｙｏｎｃｅ'), isTrue,
          reason: 'an IME left on full-width is invisible to the eye but not to '
              'a byte comparison');
    });
  });

  test('folding is idempotent and leaves ordinary text intact', () {
    expect(
        foldForLibrarySearch(foldForLibrarySearch('Sigur Rós')),
        foldForLibrarySearch('Sigur Rós'));
    expect(foldForLibrarySearch('Living With Determination'),
        'living with determination');
  });
}
