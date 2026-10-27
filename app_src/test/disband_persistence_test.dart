library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/snapshot.dart';

Track _t(int i) => Track(
      id: 't$i',
      title: 'Title $i',
      artist: 'Artist $i',
      album: 'A',
      duration: const Duration(seconds: 90),
      file: 't$i.m4a',
      cover: '',
      gainDb: 0,
    );

PlaybackSnapshot _snap({required String trackId, required List<String> queueIds}) =>
    PlaybackSnapshot(
      trackId: trackId,
      positionMs: 5000,
      queueIds: queueIds,
      queueIndex: 0,
      shuffle: false,
      artKey: 'makoto',
      savedAt: DateTime.now(),
    );

void main() {
  late Directory tmp;
  late SnapshotStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('personar_disband');
    store = SnapshotStore(directory: tmp.path);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('clearing the snapshot leaves nothing for the next launch', () async {
    await store.save(_snap(trackId: 't1', queueIds: const ['t1', 't2']));
    expect(await store.load(), isNotNull, reason: 'precondition: there IS something to resume');

    await store.clear();

    expect(await store.load(), isNull,
        reason: 'the disbanded queue is still on disk, so opening the app brings it back');
  });

  test('a snapshot with no current track and no goodbye is not resumable', () async {
    await store.save(_snap(trackId: '', queueIds: const []));

    expect(await store.load(), isNull,
        reason: 'an empty snapshot was accepted, so a disbanded state can be restored');
  });

  test('a DISBANDED state survives the round trip, and boots with NO queue', () async {
    await store.save(PlaybackSnapshot(
      trackId: '',
      positionMs: 0,
      queueIds: const [],
      queueIndex: 0,
      shuffle: false,
      artKey: '',
      savedAt: DateTime.now(),
      disbanded: true,
    ));

    final resume = await store.load();
    expect(resume, isNotNull, reason: 'the goodbye was thrown away on read');
    expect(resume!.disbanded, isTrue);

    final state = AppState()
      ..attachLibrary([for (var i = 0; i < 5; i++) _t(i)], resume: resume);
    expect(state.queue?.order, isEmpty,
        reason: 'the queue was rebuilt out of the library — that is the "new playlist" he saw come back');
    expect(state.currentTrack, isNull,
        reason: 'a disbanded boot must not come up holding a track');
  });
}
