library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/player/snapshot.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

List<Track> _lib(int n) => List.generate(n, (i) => _t('t$i'));

PlaybackSnapshot _snap({
  required String trackId,
  List<String> queueIds = const [],
  int queueIndex = 0,
  bool shuffle = false,
  String artKey = '',
}) =>
    PlaybackSnapshot(
      trackId: trackId,
      positionMs: 42000,
      queueIds: queueIds,
      queueIndex: queueIndex,
      shuffle: shuffle,
      artKey: artKey,
      savedAt: DateTime.now(),
    );

void main() {
  group('restoreOrder', () {
    test('reorders the queue to match the saved ids', () {
      final q = PlayQueue(source: _lib(5));
      q.restoreOrder(['t3', 't1', 't0']);

      expect(q.order.map((t) => t.id).toList().sublist(0, 3), ['t3', 't1', 't0']);
      expect(q.length, 5, reason: 'nothing is lost from the library');
    });

    test('ids no longer in the library are skipped, not left as holes', () {
      final q = PlayQueue(source: _lib(4));
      q.restoreOrder(['t2', 'ghost', 't0']);
      final ids = q.order.map((t) => t.id).toList();
      expect(ids.contains('ghost'), isFalse);
      expect(ids.first, 't2');
      expect(ids.length, 4);
    });

    test('an empty saved order leaves the queue alone', () {
      final q = PlayQueue(source: _lib(4));
      final before = q.order.map((t) => t.id).toList();
      q.restoreOrder(const []);
      expect(q.order.map((t) => t.id).toList(), before);
    });

    test('an all-ghost saved order falls back to the library order', () {
      final q = PlayQueue(source: _lib(3));
      q.restoreOrder(['x', 'y']);
      expect(q.order.length, 3);
      expect(q.current, isNotNull);
    });

    test('an index past the end is clamped, not a crash', () {
      final q = PlayQueue(source: _lib(3));
      q.jumpTo('t2');
      q.restoreOrder(['t0', 't1']);
      expect(q.index, lessThan(q.length));
      expect(q.current, isNotNull);
    });
  });

  group('attachLibrary with a resume', () {
    test('restores the exact track that was playing', () {
      final state = AppState();
      state.attachLibrary(
        _lib(10),
        resume: _snap(trackId: 't6', queueIds: ['t6', 't7', 't8']),
      );
      expect(state.currentTrack!.id, 't6');
    });

    test('restores shuffle mode', () {
      final state = AppState();
      state.attachLibrary(_lib(50), resume: _snap(trackId: 't2', shuffle: true));
      expect(state.queue!.isShuffled, isTrue);
    });

    test('restores the art that was on screen', () {
      if (!AppState().artSet.hasArt) {
        markTestSkipped('no art in this build, so there is no key to restore');
        return;
      }
      final state = AppState();
      state.attachLibrary(
        _lib(10),
        resume: _snap(trackId: 't1', artKey: 'yukari'),
      );
      expect(state.art?.key, 'yukari');
    });

    test('an unknown art key is ignored rather than crashing', () {
      final state = AppState();
      state.attachLibrary(
        _lib(10),
        resume: _snap(trackId: 't1', artKey: 'nobody'),
      );
      expect(state.art, state.artSet.defaultArt);
    });

    test('a track removed from the library does not break the resume', () {
      final state = AppState();
      state.attachLibrary(
        _lib(5),
        resume: _snap(trackId: 'gone', queueIds: ['gone', 't1']),
      );

      expect(state.currentTrack, isNotNull);
    });

    test('no resume at all starts from the top, unshuffled', () {
      final state = AppState();
      state.attachLibrary(_lib(8));
      expect(state.currentTrack!.id, 't0');
      expect(state.queue!.isShuffled, isFalse);
      expect(state.art, state.artSet.defaultArt);
    });

    test('a stale resume is ignored', () {
      final state = AppState();
      final old = PlaybackSnapshot(
        trackId: 't5',
        positionMs: 1000,
        queueIds: const ['t5'],
        queueIndex: 0,
        shuffle: false,
        artKey: 'yukari',
        savedAt: DateTime.now().subtract(const Duration(days: 365)),
      );
      state.attachLibrary(_lib(8), resume: old);
      expect(state.currentTrack!.id, 't0', reason: 'stale state starts clean');
    });

    test('an empty library is a state, not a crash', () {
      final state = AppState();
      state.attachLibrary(const [], resume: _snap(trackId: 't1'));
      expect(state.currentTrack, isNull);
    });
  });

  group('snapshot round trip through state', () {
    test('a snapshot taken now restores to the same track and art', () {
      final state = AppState();
      state.attachLibrary(_lib(12));
      state.nextTrack();
      state.nextTrack();
      state.nextArt();
      final playing = state.currentTrack!.id;
      if (state.art == null) {
        markTestSkipped('no art in this build, so there is no art key to round-trip');
        return;
      }
      final who = state.art!.key;

      final snap = state.snapshot();
      expect(snap.trackId, playing);
      expect(snap.artKey, who);

      final restored = AppState();
      restored.attachLibrary(_lib(12), resume: snap);
      expect(restored.currentTrack!.id, playing);
      expect(restored.art!.key, who);
    });

    test('the saved queue order matches what was playing', () {
      final state = AppState();
      state.attachLibrary(_lib(6));
      state.nextTrack();
      final snap = state.snapshot();
      expect(snap.queueIds, state.queue!.order.map((t) => t.id).toList());
      expect(snap.queueIndex, state.queue!.index);
    });

    test('snapshot before any library is attached is safe', () {
      final state = AppState();
      final snap = state.snapshot();
      expect(snap.trackId, '');
      expect(snap.queueIds, isEmpty);
    });
  });

  group('a restored queue SURVIVES THE BOOT PUBLISH', () {
    PlaybackSnapshot reversedSnap() => _snap(
          trackId: 't9',
          queueIds: ['t9', 't8', 't7', 't6', 't5', 't4', 't3', 't2', 't1', 't0'],
        );

    test('the boot context publish ADOPTS it rather than re-deriving', () {
      final state = AppState();
      state.attachLibrary(_lib(10), resume: reversedSnap());
      final restored = [for (final t in state.queue!.order) t.id];
      expect(restored.first, 't9', reason: 'the fixture did not restore — check attachLibrary');

      state.updateContext(const PlayContext(
        band: ContextBand.afternoon,
        sky: Sky.unknown,
        localHour: 14));

      expect([for (final t in state.queue!.order) t.id], restored,
          reason: 'the boot publish rebuilt the queue, so the order he left was overwritten');
      expect(state.currentTrack!.id, 't9',
          reason: 'the restored track was replaced by a re-derivation');
    });

    test('but the NEXT context move still re-derives', () {
      final state = AppState();
      state.attachLibrary(_lib(10), resume: reversedSnap());
      state.updateContext(const PlayContext(
        band: ContextBand.afternoon,
        sky: Sky.unknown,
        localHour: 14));
      final afterBoot = [for (final t in state.queue!.order) t.id];

      state.updateContext(const PlayContext(
        band: ContextBand.evening,
        sky: Sky.unknown,
        localHour: 20));

      expect([for (final t in state.queue!.order) t.id], isNot(afterBoot),
          reason: 'a real context move did not re-derive — the boot suppression was never consumed');
      expect(state.currentTrack!.id, 't9',
          reason: 'a context move must change what comes NEXT, never stop what is playing');
    });

    test('a snapshot with no queue adopts nothing, so the first publish derives', () {
      final state = AppState();
      state.attachLibrary(_lib(10), resume: _snap(trackId: 't3'));
      state.updateContext(const PlayContext(
        band: ContextBand.afternoon,
        sky: Sky.unknown,
        localHour: 14));
      expect(state.queue!.order.length, greaterThan(1),
          reason: 'nothing was restored, so the publish should have derived a real queue');
    });
  });

  group('track navigation through state', () {
    test('nextTrack and previousTrack move and notify', () {
      final state = AppState();
      state.attachLibrary(_lib(5));
      var notifications = 0;
      state.addListener(() => notifications++);

      state.nextTrack();
      expect(state.currentTrack!.id, 't1');
      state.previousTrack();
      expect(state.currentTrack!.id, 't0');
      expect(notifications, 2);
    });

    test('toggleShuffle flips and keeps the current track', () {
      final state = AppState();
      state.attachLibrary(_lib(30));
      state.nextTrack();
      final playing = state.currentTrack!.id;
      state.toggleShuffle();
      expect(state.queue!.isShuffled, isTrue);
      expect(state.currentTrack!.id, playing);
      state.toggleShuffle();
      expect(state.queue!.isShuffled, isFalse);
    });

    test('navigation before a library is attached does nothing', () {
      final state = AppState();
      state.nextTrack();
      state.previousTrack();
      state.toggleShuffle();
      expect(state.currentTrack, isNull);
    });
  });

  group('skin changes reset the art safely', () {
    test('switching skin moves to that skin protagonist', () {
      final state = AppState();
      state.attachLibrary(_lib(5));
      state.selectArt(3);
      state.chooseSkinManually(SkinId.crimson);
      expect(state.art, state.artSet.defaultArt);
      expect(state.artSet.skinId, SkinId.crimson);
    });
  });
}
