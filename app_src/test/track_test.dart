import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';

const _sample = '''
{
  "version": 1,
  "track_count": 3,
  "tracks": [
    { "id": "a1", "title": "Joy", "artist": "ATLUS Sound Team",
      "album": "Persona 3 Reload", "duration_s": 178.52,
      "file": "ATLUS Sound Team/Persona 3 Reload/Joy.opus",
      "cover": "covers/aaaa.jpg", "gain_db": -6.3 },
    { "id": "b2", "title": "Iris Out", "artist": "Kenshi Yonezu",
      "album": "IRIS OUT", "duration_s": 151.608,
      "file": "Kenshi Yonezu/IRIS OUT/IRIS OUT.mp3",
      "cover": "covers/bbbb.jpg", "gain_db": -8.2 },
    { "id": "c3", "title": "\\u30ad\\u30df\\u306e\\u8a18\\u61b6", "artist": "ATLUS Sound Team",
      "album": "Persona 3 Reload", "duration_s": 285.1,
      "file": "ATLUS Sound Team/Persona 3 Reload/\\u30ad\\u30df\\u306e\\u8a18\\u61b6.opus",
      "cover": "", "gain_db": null }
  ]
}
''';

void main() {
  group('manifest parsing', () {
    test('reads every track', () {
      final tracks = Track.listFromManifest(_sample);
      expect(tracks, hasLength(3));
      expect(tracks[0].title, 'Joy');
      expect(tracks[0].artist, 'ATLUS Sound Team');
      expect(tracks[0].album, 'Persona 3 Reload');
    });

    test('converts duration seconds into a Duration', () {
      final tracks = Track.listFromManifest(_sample);
      expect(tracks[0].duration.inMilliseconds, 178520);
      expect(tracks[1].duration.inMilliseconds, 151608);
    });

    test('keeps relative file paths untouched', () {
      final tracks = Track.listFromManifest(_sample);
      expect(tracks[0].file, 'ATLUS Sound Team/Persona 3 Reload/Joy.opus');
    });

    test('null gain is allowed and stays null', () {
      final tracks = Track.listFromManifest(_sample);
      expect(tracks[0].gainDb, -6.3);
      expect(tracks[2].gainDb, isNull);
    });

    test('non-ascii titles survive', () {
      final tracks = Track.listFromManifest(_sample);
      expect(tracks[2].title, '\u30ad\u30df\u306e\u8a18\u61b6');
    });

    test('missing track list yields empty, not a crash', () {
      expect(Track.listFromManifest('{"version":1}'), isEmpty);
      expect(Track.listFromManifest('{"tracks":[]}'), isEmpty);
    });

    test('entries without a file are discarded', () {
      final tracks = Track.listFromManifest(
        '{"tracks":[{"title":"x","file":""},{"title":"y","file":"a/b.opus"}]}',
      );
      expect(tracks, hasLength(1));
      expect(tracks.single.title, 'y');
    });
  });

  group('search', () {
    final tracks = Track.listFromManifest(_sample);

    test('empty query matches everything', () {
      expect(tracks.every((t) => t.matches('')), isTrue);
    });

    test('matches on title', () {
      expect(tracks.where((t) => t.matches('joy')).length, 1);
    });

    test('matches on artist, case-insensitively', () {
      expect(tracks.where((t) => t.matches('kenshi')).length, 1);
    });

    test('matches on album', () {
      expect(tracks.where((t) => t.matches('IRIS OUT')).length, 1);
    });

    test('matches on the folder part of the path', () {
      expect(tracks.where((t) => t.matches('Persona 3 Reload')).length, 2);
    });

    test('multiple terms must all match', () {
      expect(tracks.where((t) => t.matches('joy atlus')).length, 1);
      expect(tracks.where((t) => t.matches('joy kenshi')).length, 0);
    });

    test('non-ascii title is searchable', () {
      expect(tracks.where((t) => t.matches('\u30ad\u30df')).length, 1);
    });
  });
}
