// Hostile lyrics QA: timestamps from a stranger's file, a corrupt cache, and a
// track id used as a filename.
@Tags(['adversarial'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarar/library/lyrics.dart';

http.Client hitClient(String synced) => MockClient((_) async => http.Response(
      jsonEncode([
        {
          'trackName': 'Title',
          'artistName': 'Artist',
          'syncedLyrics': synced,
          'plainLyrics': '',
          'duration': 200,
        }
      ]),
      200,
    ));

void main() {
  group('timestamps cannot overflow a Duration', () {
    for (final stamp in ['1e400:00', '999999999999999999999:00', '1e308:00']) {
      test('[$stamp] is refused, not thrown', () {
        expect(
          () => LyricLine.parseAll('[$stamp]line'),
          returnsNormally,
          reason: 'a stranger\'s LRC file must not throw out of the parser',
        );
      });
    }

    test('the ordinary shapes still parse', () {
      expect(LyricLine.parseAll('[00:12]hi').single.at,
          const Duration(seconds: 12));
      expect(LyricLine.parseAll('[1:02:03.50]hi').single.at,
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500));
      expect(LyricLine.parseAll('[00:01][00:02]hi').length, 2);
    });

    test('a negative stamp is refused', () {
      expect(LyricLine.parseAll('[-00:01]hi'), isEmpty);
    });

    test('a line that is not a stamp is not half-read', () {
      expect(LyricLine.parseAll('[ar:Someone]hi'), isEmpty);
    });

    test('indexAt does not assume the caller sorted the lines', () {
      final lyrics = Lyrics(lines: [
        const LyricLine(Duration(seconds: 30), 'late'),
        const LyricLine(Duration(seconds: 1), 'early'),
      ]);
      expect(lyrics.indexAt(const Duration(seconds: 29)), -1,
          reason: 'a highlight over an unsorted list is wrong, but must not throw');
    });
  });

  group('a corrupt lyrics cache is a miss, not a crash', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('sonarar-lyrics'));
    tearDown(() => root.deleteSync(recursive: true));

    LyricsService service() =>
        LyricsService(cacheDirectory: '${root.path}/cache', client: hitClient(''));

    test('wrong-typed cached lines are ignored', () async {
      final file = File('${root.path}/cache/lyrics/t1.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({
          'lines': [
            ['not-a-number', 5],
            [1000, 'ok'],
          ],
          'plain': 7,
        }));

      expect(file.existsSync(), isTrue);
      await expectLater(
        service().forTrack(trackId: 't1', title: 'Title', artist: 'Artist'),
        completes,
        reason: 'a half-written cache entry must not break lyrics for the track',
      );
    });

    test('a track id cannot write its cache outside the cache folder', () async {
      final svc = LyricsService(
        cacheDirectory: '${root.path}/cache',
        client: hitClient('[00:01]hi'),
      );
      await svc.forTrack(
        trackId: '../../escape',
        title: 'Title',
        artist: 'Artist',
      );
      final escaped = File('${root.path}/escape.json');
      expect(escaped.existsSync(), isFalse,
          reason: 'a track id is not a path');
    });

    test('a hostile LRCLIB row is handled, not thrown', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode([
              {
                'trackName': 'Title',
                'artistName': 'Artist',
                'syncedLyrics': 123,
                'plainLyrics': ['not', 'text'],
                'duration': 'long',
              }
            ]),
            200,
          ));
      final service = LyricsService(cacheDirectory: null, client: client);
      await expectLater(
        service.forTrack(trackId: 'x', title: 'Title', artist: 'Artist'),
        completes,
      );
    });
  });
}
