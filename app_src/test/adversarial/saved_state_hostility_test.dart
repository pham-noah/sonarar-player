// Hostile saved-state QA: prefs.json and playlists.json are files a user can
// edit, a crash can truncate, or an old build can leave half-written.
@Tags(['adversarial'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/playlists.dart';

void main() {
  group('prefs decoding is total', () {
    final hostile = <Object?>[
      null,
      'text',
      42,
      [],
      {},
      {'crossfade_seconds': double.nan},
      {'crossfade_seconds': double.infinity},
      {'crossfade_seconds': -999},
      {'crossfade_seconds': '12'},
      {'sleep_timer_minutes': 1 << 62},
      {'locale': 'xx-YY'},
      {'locale': 7},
      {'pinned_playlists': 'nope'},
      {'pinned_playlists': ['a', 3, null, '']},
      {'palette': -5},
      {'official_only': 'yes'},
      {'prefer_music_videos': true},
      {'unknown_key': {'nested': true}},
      {1: 'non-string key'},
    ];

    for (final raw in hostile) {
      test('case ${hostile.indexOf(raw)} does not throw', () {
        expect(() => AppPrefs.fromJson(raw), returnsNormally);
      });
    }

    test('out-of-range numbers are clamped, not stored', () {
      final p = AppPrefs.fromJson({
        'crossfade_seconds': 999,
        'sleep_timer_minutes': 0,
        'palette': -4,
      });
      expect(p.crossfadeSeconds, 12);
      expect(p.sleepTimerMinutes, 5);
      expect(p.paletteIndex, 0);
    });

    test('an unknown locale follows the phone instead of guessing', () {
      expect(AppPrefs.fromJson({'locale': 'xx-YY'}).locale, isNull);
      expect(AppPrefs.fromJson({'locale': 'ja'}).locale, 'ja');
    });

    test('a saved file survives save/load with the same meaning', () {
      final original = AppPrefs.initial.copyWith(
        crossfadeSeconds: 7,
        locale: 'vi',
        pinnedPlaylistIds: const ['a', 'b'],
        spectrumSmoothness: 88,
      );
      final again = AppPrefs.fromJson(jsonDecode(jsonEncode(original.toJson())));
      expect(again.toJson(), original.toJson());
    });

    test('copyWith cannot write what fromJson would clamp away', () {
      final p = AppPrefs.initial.copyWith(crossfadeSeconds: 99);
      expect(p.crossfadeSeconds, 12);
    });
  });

  group('playlist decoding is total', () {
    test('a file of junk items keeps the valid ones', () {
      final lists = PlaylistStore.decode(jsonEncode({
        'playlists': [
          1,
          'x',
          null,
          {'id': 5},
          {'id': 'a', 'name': '   '},
          {
            'id': 'b',
            'name': 'B',
            'track_ids': ['t1', 't1', 5, '', 't2'],
          },
          {'id': 'c', 'name': 'C', 'track_ids': 'not-a-list'},
        ],
      }));

      expect(lists.all.map((p) => p.id), ['b', 'c']);
      expect(lists.byId('b')!.trackIds, ['t1', 't2'],
          reason: 'a repeated id in the file was kept twice');
      expect(lists.byId('c')!.trackIds, isEmpty);
    });

    test('duplicate playlist ids collapse to the first', () {
      final lists = PlaylistStore.decode(jsonEncode({
        'playlists': [
          {'id': 'a', 'name': 'First'},
          {'id': 'a', 'name': 'Second'},
        ]
      }));
      expect(lists.length, 1);
      expect(lists.byId('a')!.name, 'First');
    });

    test('a root that is not an object reads as no playlists', () {
      expect(PlaylistStore.decode('[]').length, 0);
      expect(PlaylistStore.decode('"hello"').length, 0);
    });

    test('broken JSON is a typed FormatException the store catches', () {
      expect(() => PlaylistStore.decode('{"playlists": ['),
          throwsA(isA<FormatException>()));
    });

    test('a name of absurd length does not break the list', () {
      final lists = PlaylistStore.decode(jsonEncode({
        'playlists': [
          {'id': 'a', 'name': 'x' * 100000}
        ]
      }));
      expect(lists.byId('a')!.name.length, 100000);
    });

    test('a playlist edit outside the list is refused', () {
      final p = Playlist(id: 'a', name: 'A', trackIds: ['t1', 't2']);
      expect(p.move(-1, 0), isFalse);
      expect(p.move(0, 5), isFalse);
      expect(p.trackIds, ['t1', 't2']);
    });
  });
}
