library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/player/snapshot.dart';

PlaybackSnapshot _snap({double volume = 1.0}) => PlaybackSnapshot(
      trackId: 't1',
      positionMs: 1000,
      queueIds: const ['t1', 't2'],
      queueIndex: 0,
      shuffle: false,
      artKey: 'art',
      savedAt: DateTime.now(),
      volume: volume,
    );

void main() {
  group('volume round-trips', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('snap'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a saved volume is the volume that loads', () async {
      final store = SnapshotStore(directory: dir.path);
      await store.save(_snap(volume: 0.42));

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!.volume, closeTo(0.42, 0.0001));
    });

    test('muted stays muted across a round trip', () async {
      final store = SnapshotStore(directory: dir.path);
      await store.save(_snap(volume: 0.0));

      final loaded = await store.load();
      expect(loaded!.volume, 0.0,
          reason: 'a volume of zero must not be read back as the default 1.0');
    });
  });

  group('an older snapshot still resumes', () {
    test('a snapshot with no volume key loads at full volume', () async {
      final dir = Directory.systemTemp.createTempSync('snap');
      addTearDown(() => dir.deleteSync(recursive: true));

      File('${dir.path}/playback_state.json').writeAsStringSync('''
{"version":1,"track_id":"t9","position_ms":5000,
 "queue_ids":["t9"],"queue_index":0,"shuffle":true,
 "character_key":"k","saved_at":"2026-10-02T10:00:00.000"}
''');

      final loaded = await SnapshotStore(directory: dir.path).load();
      expect(loaded, isNotNull, reason: 'a pre-volume save must still resume');
      expect(loaded!.trackId, 't9');
      expect(loaded.positionMs, 5000);
      expect(loaded.volume, 1.0);
    });

    test('a nonsense volume is clamped, not obeyed', () async {
      final dir = Directory.systemTemp.createTempSync('snap');
      addTearDown(() => dir.deleteSync(recursive: true));

      File('${dir.path}/playback_state.json').writeAsStringSync('''
{"version":1,"track_id":"t9","position_ms":0,
 "queue_ids":["t9"],"queue_index":0,"shuffle":false,
 "character_key":"k","saved_at":"2026-10-02T10:00:00.000","volume":-3.0}
''');

      final loaded = await SnapshotStore(directory: dir.path).load();

      expect(loaded!.volume, 0.0);
    });
  });
}
