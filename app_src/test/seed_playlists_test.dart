@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const Map<String, int> kExpected = {
  'p3r': 80,
  'p4r': 52,
  'p5r': 109,
  'weathering': 31,
  'us_uk': 150,
  'vpop': 68,
  'kpop': 30,
  'jpop': 98,
};

const Set<String> kVariantIds = {
  'v_acoustic',
  'v_instrumental',
  'v_rain',
  'v_snow',
  'v_arrange',
  'v_long',
  'v_short',

  'v_morning',
  'v_afternoon',
  'v_evening',
};

const Set<String> kConditionIds = {'home', 'gym', 'uni', 'commuting'};

const Set<String> kDeliberatelyEmpty = {
  'v_acoustic',
  'v_snow',
  'v_arrange',
  'v_morning',
  'v_afternoon',
  'v_evening',
  ...kConditionIds,
};

Set<String> get _gameIds => kExpected.keys.toSet();

void main() {
  final seed = File('assets/config/playlists.json');
  final manifest = File('test/fixtures/library_manifest.json');

  if (!seed.existsSync() || !manifest.existsSync()) {
    test('seed probe', () {
      // ignore: avoid_print
      print('NO SEED OR MANIFEST — skipping');
    });
    return;
  }

  final decoded = jsonDecode(seed.readAsStringSync()) as Map<String, dynamic>;
  final playlists = (decoded['playlists'] as List)
      .cast<Map<String, dynamic>>();

  final manifestJson =
      jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  final libraryIds = {
    for (final t in (manifestJson['tracks'] as List)) (t as Map)['id'] as String,
  };

  test('the seed ships every playlist, once', () {
    expect(playlists.map((p) => p['id']).toSet(), {...kExpected.keys, ...kVariantIds, ...kConditionIds});
    for (final p in playlists) {
      final id = p['id'] as String;
      expect(p['name'], isNotEmpty);
      final size = (p['track_ids'] as List).length;
      final want = kExpected[id];
      if (want != null) {
        expect(size, want,
            reason: '${p['name']} changed size — regenerate and update the count');
      } else if (!kDeliberatelyEmpty.contains(id)) {
        expect(size, greaterThan(0), reason: '${p['name']} ships empty');
      } else {
        expect(size, 0,
            reason: '${p['name']} is meant to be an empty container until such recordings exist');
      }
    }
  });

  test('no track id is a ghost, and none is listed twice in one playlist', () {
    for (final p in playlists) {
      final ids = (p['track_ids'] as List).cast<String>();
      expect(ids.toSet().length, ids.length, reason: 'duplicate id in ${p['name']}');
      final ghosts = ids.where((i) => !libraryIds.contains(i));
      expect(ghosts, isEmpty,
          reason: '${p['name']} points at ids not in the library — re-run '
              'tools/build_playlists.py');
    }
  });

  test('no track is claimed by two PARTITIONING playlists', () {
    final owners = <String, List<String>>{};
    for (final p in playlists) {
      if (!_gameIds.contains(p['id'])) continue;
      for (final id in (p['track_ids'] as List).cast<String>()) {
        owners.putIfAbsent(id, () => []).add(p['name'] as String);
      }
    }
    final shared = owners.entries.where((e) => e.value.length > 1);
    expect(shared, isEmpty,
        reason: 'a track in two playlists: '
            '${shared.map((e) => '${e.value.join("+")} ${e.key}').join(", ")}');
  });

  test('the PARTITIONING lists cover the library and the leftovers are the known singles', () {
    final covered = <String>{};
    for (final p in playlists) {
      if (!_gameIds.contains(p['id'])) continue;
      covered.addAll((p['track_ids'] as List).cast<String>());
    }
    expect(libraryIds.length - covered.length, 7);
  });

  test('every variant list is a subset of the library and overlaps a game list', () {
    final gameCovered = <String>{};
    for (final p in playlists) {
      if (_gameIds.contains(p['id'])) {
        gameCovered.addAll((p['track_ids'] as List).cast<String>());
      }
    }
    for (final p in playlists.where((p) =>
        kVariantIds.contains(p['id']) &&
        !kDeliberatelyEmpty.contains(p['id']))) {
      final ids = (p['track_ids'] as List).cast<String>();
      expect(ids.every(libraryIds.contains), isTrue,
          reason: '${p['name']} points at a track the library does not have');
      expect(ids.any(gameCovered.contains), isTrue,
          reason: '${p['name']} shares nothing with any game list — it is not a view of them');
    }
  });
}
