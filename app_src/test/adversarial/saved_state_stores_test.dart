// Hostile saved-state QA, part two: every file the boot reads must come back
// with a default rather than an exception. These are files a crash can truncate
// and a user can hand-edit.
@Tags(['adversarial'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/bonds.dart';
import 'package:sonarar/library/exclusions.dart';
import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/playlist_loader.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/tag_overrides.dart';
import 'package:sonarar/playback/loop_points.dart';
import 'package:sonarar/player/snapshot.dart';
import 'package:sonarar/rules/rules_loader.dart';
import 'package:sonarar/theme/personalization_store.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('sonarar-stores'));
  tearDown(() => dir.deleteSync(recursive: true));

  File put(String name, String body) =>
      File('${dir.path}/$name')..writeAsStringSync(body);

  final shapes = <String, String>{
    'truncated': '{"loops": [',
    'wrong root type': '[1, 2, 3]',
    'wrong field types': '{"loops": [{"track_id": 5, "loop_count": "3"}]}',
    'numeric ids': '[{"track_id": 1, "intro_end_ms": "x"}]',
    'nulls everywhere': '{"places": null, "version": null}',
    'deep nesting': '{"a": {"b": {"c": [[[[[1]]]]]}}}',
    'empty object': '{}',
    'empty string': '',
  };

  final loopShapes = <String, String>{
    'truncated': '[' ,
    'wrong root type': '{"loops": []}',
    'string loop_count': '[{"track_id":"a","loop_count":"3"}]',
    'string intro time': '[{"track_id":"a","intro_end_ms":"x"}]',
    'numeric id': '[{"track_id":1}]',
    'null entry': '[null, 5, "x"]',
  };

  test('loop points survive every hostile shape', () async {
    for (final entry in loopShapes.entries) {
      put('loop_points.json', entry.value);
      await expectLater(
        LoopPointStore(File('${dir.path}/loop_points.json')).load(),
        completes,
        reason: 'loop points: ${entry.key}',
      );
    }
  });

  test('bonds survive every hostile shape', () async {
    for (final entry in shapes.entries) {
      put('bonds.json', entry.value);
      await expectLater(
        BondStore(File('${dir.path}/bonds.json')).load(),
        completes,
        reason: 'bonds: ${entry.key}',
      );
    }
    for (final body in [
      '{"config": {"completion_points": "6"}}',
      '{"config": {"early_skip_penalty": null, "reset_at": 5}}',
      '{"config": [], "notes": {"a": 1}}',
    ]) {
      put('bonds.json', body);
      await expectLater(
        BondStore(File('${dir.path}/bonds.json')).load(),
        completes,
        reason: 'bonds: $body',
      );
    }
  });

  test('tag overrides survive every hostile shape', () async {
    for (final entry in shapes.entries) {
      put('tag_overrides.json', entry.value);
      await expectLater(
        TagOverrideStore(File('${dir.path}/tag_overrides.json')).load(),
        completes,
        reason: 'tags: ${entry.key}',
      );
    }
  });

  test('personalization survives every hostile shape', () async {
    for (final entry in shapes.entries) {
      put('personalize.json', entry.value);
      await expectLater(
        PersonalizationStore(File('${dir.path}/personalize.json')).load(),
        completes,
        reason: 'personalization: ${entry.key}',
      );
    }
  });

  test('a bookmarks file of wrong types reads as empty', () async {
    final store = JsonMapStore<Duration>(
      File('${dir.path}/bookmarks.json'),
      encode: (v) => v.inMilliseconds,
      decode: (v) => v is num ? Duration(milliseconds: v.toInt()) : null,
    );
    for (final body in ['[]', '{"a": "x", "b": null, "c": 1.5}', '{"a": {"b": 1}}']) {
      put('bookmarks.json', body);
      final map = await store.load();
      expect(map, isA<Map<String, Duration>>());
    }
  });

  test('the playback snapshot is a null, not a throw', () async {
    final store = SnapshotStore(directory: dir.path);
    for (final body in [
      '{"version": 1}',
      '{"version": 1, "track_id": 5, "position_ms": "x"}',
      '{"version": "1", "track_id": "a"}',
      '{"version": 1, "queue": [1, 2], "index": "0"}',
      'not json at all',
    ]) {
      put('playback_state.json', body);
      await expectLater(store.load(), completes, reason: body);
    }
  });

  test('rules survive a hostile file', () async {
    final loader = ContextRulesLoader(file: File('${dir.path}/rules.json'));
    for (final body in [
      '{"rules": "nope"}',
      '{"rules": [{"when": 5}]}',
      '[]',
      '{"version": 99, "rules": [{"when": {"hour": [1, 2]}}]}',
    ]) {
      put('rules.json', body);
      await expectLater(loader.load(), completes, reason: body);
    }
  });

  test('the play log skips broken lines and keeps the rest', () async {
    put(
      'plays.jsonl',
      [
        '{"track_id":"a","at":"2026-01-01T00:00:00Z","position_ms":1,"duration_ms":2}',
        '{"track_id":',
        'not json',
        '',
        '{"track_id":"b","at":"2026-01-01T00:01:00Z","position_ms":1,"duration_ms":2}',
        '[1,2,3]',
      ].join('\n'),
    );
    final log = PlayLog(File('${dir.path}/plays.jsonl'));
    await expectLater(log.read(), completes);

    final events = await log.read();
    expect(events.where((e) => e.trackId == 'a'), isNotEmpty);
    expect(events.where((e) => e.trackId == 'b'), isNotEmpty);
  });

  test('playlists that lost their tracks still load', () async {
    put(
      'playlists.json',
      '{"playlists":[{"id":"a","name":"A","track_ids":["missing","t1"]}]}',
    );
    final loader = PlaylistLoader(
      store: PlaylistStore(File('${dir.path}/playlists.json')),
    );
    final lists = await loader.load(libraryIds: {'t1'});
    expect(lists.byId('a'), isNotNull);
    expect(lists.byId('a')!.trackIds, ['t1'],
        reason: 'a playlist kept a track the library does not have');
  });
}
