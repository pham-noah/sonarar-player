@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';

SearchHit _hit(String title, {String channel = 'Some Channel'}) => SearchHit(
      id: 'x', title: title, channel: channel, duration: const Duration(minutes: 3),
    );

void main() {
  group('the AUDIO release is accepted — the half the old name denied', () {
    test('a bare official audio upload', () {
      expect(_hit('Last Surprise (Official Audio)').looksLikeOfficialRelease, isTrue);
    });

    test('a topic channel carries the label audio, whatever the title', () {
      expect(_hit('Rivers In the Desert', channel: 'ATLUS Sound Team - Topic')
          .looksLikeOfficialRelease, isTrue);
    });

    test('a soundtrack upload', () {
      expect(_hit('Persona 5 OST — Beneath the Mask (Official Soundtrack)')
          .looksLikeOfficialRelease, isTrue);
    });

    test('a VEVO channel', () {
      expect(_hit('Some Song', channel: 'ArtistVEVO').looksLikeOfficialRelease, isTrue);
    });
  });

  group('the VIDEO release still counts', () {
    test('an official music video', () {
      expect(_hit('Song (Official Music Video)').looksLikeOfficialRelease, isTrue);
    });

    test('an MV marker', () {
      expect(_hit('Song 【MV】').looksLikeOfficialRelease, isTrue);
    });
  });

  group('the things it is meant to refuse', () {
    test('a plain re-upload with no marker at all', () {
      expect(_hit('song but pitched down lol').looksLikeOfficialRelease, isFalse);
    });

    test('a lyric video is not an official release', () {
      expect(_hit('Song (Lyrics)').looksLikeOfficialRelease, isFalse);
    });

    test('a random channel is not a topic channel', () {
      expect(_hit('Song', channel: 'Random Uploads 2026').looksLikeOfficialRelease, isFalse);
    });
  });
}
