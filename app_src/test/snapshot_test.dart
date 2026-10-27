library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/player/snapshot.dart';

void main() {
  late Directory tmp;
  late SnapshotStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('personar_snap');
    store = SnapshotStore(directory: tmp.path);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  PlaybackSnapshot sample({
    String trackId = 't7',
    int positionMs = 84000,
    List<String> queueIds = const ['t1', 't2', 't7', 't9'],
    int queueIndex = 2,
    bool shuffle = true,
    String artKey = 'mitsuru',
  }) =>
      PlaybackSnapshot(
        trackId: trackId,
        positionMs: positionMs,
        queueIds: queueIds,
        queueIndex: queueIndex,
        shuffle: shuffle,
        artKey: artKey,
        savedAt: DateTime.now(),
      );

  group('round trip', () {
    test('everything survives a save and load', () async {
      await store.save(sample());
      final got = await store.load();

      expect(got, isNotNull);
      expect(got!.trackId, 't7');
      expect(got.positionMs, 84000);
      expect(got.queueIds, ['t1', 't2', 't7', 't9']);
      expect(got.queueIndex, 2);
      expect(got.shuffle, isTrue);
      expect(got.artKey, 'mitsuru');
    });

    test('position is restored to the second, not rounded away', () async {
      await store.save(sample(positionMs: 84317));
      final got = await store.load();
      expect(got!.positionMs, 84317);
    });

    test('shuffle off survives too', () async {
      await store.save(sample(shuffle: false));
      expect((await store.load())!.shuffle, isFalse);
    });

    test('non-ascii ids survive the round trip', () async {
      await store.save(sample(trackId: '全ての人の魂の戦い'));
      expect((await store.load())!.trackId, '全ての人の魂の戦い');
    });
  });

  group('no state is a normal state', () {
    test('loading before anything is saved returns null', () async {
      expect(await store.load(), isNull);
    });

    test('clearing works and is safe to repeat', () async {
      await store.save(sample());
      await store.clear();
      expect(await store.load(), isNull);
      await store.clear();
      expect(await store.load(), isNull);
    });
  });

  group('a bad file must never break launch', () {
    test('corrupt JSON returns null instead of throwing', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync('{ not json');
      expect(await store.load(), isNull);
    });

    test('an empty file returns null', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync('');
      expect(await store.load(), isNull);
    });

    test('a JSON array (wrong shape) returns null', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync('[1,2,3]');
      expect(await store.load(), isNull);
    });

    test('a future schema version is ignored, not half-read', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync(
        '{"version": 99, "track_id": "t1", "position_ms": 5}',
      );
      expect(await store.load(), isNull);
    });

    test('a snapshot with no track id is rejected', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync(
        '{"version": 1, "position_ms": 100}',
      );
      expect(await store.load(), isNull);
    });

    test('missing optional fields fall back instead of throwing', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync(
        '{"version": 1, "track_id": "t3"}',
      );
      final got = await store.load();
      expect(got, isNotNull);
      expect(got!.trackId, 't3');
      expect(got.positionMs, 0);
      expect(got.queueIds, isEmpty);
      expect(got.shuffle, isFalse);
    });

    test('a junk queue value does not poison the snapshot', () async {
      File('${tmp.path}/playback_state.json').writeAsStringSync(
        '{"version": 1, "track_id": "t3", "queue_ids": "not-a-list"}',
      );
      final got = await store.load();
      expect(got, isNotNull);
      expect(got!.queueIds, isEmpty);
    });
  });

  group('staleness', () {
    test('a fresh snapshot is not stale', () {
      expect(sample().isStale, isFalse);
    });

    test('an ancient snapshot is stale, so playback starts clean', () {
      final old = PlaybackSnapshot(
        trackId: 't1',
        positionMs: 1000,
        queueIds: const ['t1'],
        queueIndex: 0,
        shuffle: false,
        artKey: 'makoto',
        savedAt: DateTime.now().subtract(const Duration(days: 90)),
      );
      expect(old.isStale, isTrue);
    });
  });

  group('write safety', () {
    test('saving creates the directory if it is missing', () async {
      final nested = '${tmp.path}/deep/nested';
      final s = SnapshotStore(directory: nested);
      await s.save(sample());
      expect(Directory(nested).existsSync(), isTrue);
      expect((await s.load())!.trackId, 't7');
    });

    test('overwriting replaces the old snapshot, not appends', () async {
      await store.save(sample(trackId: 'first'));
      await store.save(sample(trackId: 'second'));
      expect((await store.load())!.trackId, 'second');
      final files = tmp.listSync().whereType<File>().toList();
      expect(files.length, 1, reason: 'one file, overwritten');
    });
  });
}
