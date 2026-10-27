library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:sonarar/library/lyrics.dart';

void main() {
  group('parsing LRC', () {
    test('a timed line parses to a duration and text', () {
      final l = LyricLine.parse('[00:30.23] It\'s now, or it\'s never')!;
      expect(l.at, const Duration(seconds: 30, milliseconds: 230));
      expect(l.text, 'It\'s now, or it\'s never');
    });

    test('a comma fraction parses the same as a dot', () {
      expect(LyricLine.parse('[00:30,23] x')!.at,
          const Duration(seconds: 30, milliseconds: 230));
    });

    test('a whole-second stamp parses', () {
      expect(LyricLine.parse('[01:05] x')!.at, const Duration(minutes: 1, seconds: 5));
    });

    test('a MALFORMED line returns null rather than throwing', () {
      expect(LyricLine.parse('not a lyric line'), isNull);
      expect(LyricLine.parse('[bad] x'), isNull);
      expect(LyricLine.parse('[00:zz] x'), isNull);
      expect(LyricLine.parse('[]'), isNull);
    });

    test('an UNTIMED line returns null, so it can be skipped', () {
      expect(LyricLine.parse('just some words'), isNull);
    });
  });

  group('normaliseQuery — the measured failures', () {
    test('strips a cover credit', () {
      final q = normaliseQuery('プロポーズ/ なとり cover 9Lana');
      expect(q.toLowerCase(), isNot(contains('cover')));
      expect(q, contains('プロポーズ'));
    });

    test('collapses a `...` join to the LONGEST title, not the first', () {
      expect(normaliseQuery('nàng thơ... trời giấu trời mang đi'),
          'trời giấu trời mang đi');
      expect(normaliseQuery('trời giấu trời mang đi... another song'),
          'trời giấu trời mang đi');
    });

    test('strips a (feat. …) trailer', () {
      final q = normaliseQuery('Song Name (feat. Someone)');
      expect(q, 'Song Name');
    });

    test('the feature strip runs BEFORE the ... split', () {
      final q = normaliseQuery('a... b (feat. c)');
      expect(q, isNot(contains('feat')));
    });

    test('an ordinary title is LEFT ALONE', () {
      expect(normaliseQuery('Rivers In the Desert'), 'Rivers In the Desert');
      expect(normaliseQuery('Last Surprise'), 'Last Surprise');
      expect(normaliseQuery('anh nhà ở đâu thế'), 'anh nhà ở đâu thế');
    });

    test('a title that would normalise to EMPTY falls back to the original', () {
      expect(normaliseQuery('cover'), 'cover');
      expect(normaliseQuery('...'), '...');
    });
  });

  group('the highlight index', () {
    Lyrics three() => Lyrics(lines: const [
          LyricLine(Duration(seconds: 10), 'one'),
          LyricLine(Duration(seconds: 20), 'two'),
          LyricLine(Duration(seconds: 30), 'three'),
        ]);

    test('before the first line there is NO highlight', () {
      expect(three().indexAt(const Duration(seconds: 5)), -1);
    });

    test('it advances with the position', () {
      expect(three().indexAt(const Duration(seconds: 10)), 0);
      expect(three().indexAt(const Duration(seconds: 19)), 0);
      expect(three().indexAt(const Duration(seconds: 25)), 1);
    });

    test('past the end it holds the LAST line', () {
      expect(three().indexAt(const Duration(minutes: 5)), 2);
    });
  });

  group('an instrumental is answered WITHOUT a request', () {
    test('the app already knows, from the variant tag', () async {
      final result = await LyricsService(
        cacheDirectory: null,
        client: _ExplodingClient(),
      ).forTrack(
        trackId: 'x',
        title: 'Life Will Change -instrumental version-',
        artist: 'ATLUS Sound Team',
        instrumental: true,
      );
      expect(result, isNotNull);
      expect(result!.instrumental, isTrue,
          reason: 'an instrumental should be a FACT, not a failed lookup');
      expect(result.isEmpty, isTrue);
    });
  });
}

class _ExplodingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('the network was reached when it should not have been');
  }
}
