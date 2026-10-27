library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue_mode.dart';
import 'package:sonarar/player/snapshot.dart';
import 'package:sonarar/library/playlists.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'a',
      album: 'b',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

void main() {
  group('the mode the app starts in', () {
    test('the setting supplies the starting mode', () {
      final state = AppState()..attachLibrary(_library(4));
      state.applyQueuePrefs(defaultMode: false, refill: false);
      expect(state.mode, QueueMode.fixed);
    });

    test('and it does NOT overwrite a mode already chosen this session', () {
      final state = AppState()..attachLibrary(_library(4));
      state.setMode(QueueMode.fixed);
      state.applyQueuePrefs(defaultMode: true, refill: false);
      expect(state.mode, QueueMode.fixed,
          reason: 'the boot default overrode the listener\'s own switch');
    });

    test('a restored mode wins over the default', () {
      final state = AppState()..attachLibrary(_library(4));
      state.applyQueuePrefs(defaultMode: true, refill: false);
      state.restoreMode(QueueMode.fixed);
      state.applyQueuePrefs(defaultMode: true, refill: false);
      expect(state.mode, QueueMode.fixed);
    });
  });

  group('the mode survives a restart', () {
    test('the snapshot carries it, as a NAME rather than an index', () {
      final state = AppState()..attachLibrary(_library(4));
      state.setMode(QueueMode.fixed);
      state.setQueueForTest(_library(4));
      final snap = state.snapshot();
      expect(snap.queueMode, 'fixed');

      final back = PlaybackSnapshot.fromJson(snap.toJson())!;
      expect(back.queueMode, 'fixed');
    });

    test('a snapshot written BEFORE the field existed reads as the default, not as a crash', () {
      final json = {
        'track_id': 't0',
        'position_ms': 0,
        'queue_ids': <String>[],
        'queue_index': 0,
        'shuffle': false,
        'character_key': 'x',
        'saved_at': DateTime.now().toIso8601String(),
      };
      final snap = PlaybackSnapshot.fromJson(json);
      expect(snap, isNotNull);
      expect(snap!.queueMode, 'dynamic');
    });
  });

  group('what happens when a queue ends', () {
    test('the setting decides, and it is read live rather than copied in', () {
      final state = AppState()..attachLibrary(_library(4));
      state.applyQueuePrefs(defaultMode: true, refill: false);
      expect(state.refillWhenQueueEnds, isFalse);
      state.applyQueuePrefs(defaultMode: true, refill: true);
      expect(state.refillWhenQueueEnds, isTrue,
          reason: 'flipping the switch did not take effect until a restart');
    });

    test('refilling builds a queue from the context with the ended track at its head', () {
      final state = AppState()..attachLibrary(_library(30));
      state.setQueueForTest([_t('t0')]);

      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t1']),
      ]));
      state.updateContext(const PlayContext(
        band: ContextBand.morning, sky: Sky.unknown, localHour: 9));
      final ok = state.refillFromContext();
      expect(ok, isTrue, reason: 'the context had nothing to refill with');
      expect(state.queue!.order.length, greaterThan(1));

      expect(state.queue!.order.first.id, 't0',
          reason: 'the ended track was dropped instead of being kept as the past');
      expect(state.queue!.current!.id, isNot('t0'),
          reason: 'refilling left the ended track current, so the music would replay');
    });

    test('and it refuses when there is nothing to refill with', () {
      final state = AppState();

      expect(state.refillFromContext(), isFalse);
    });
  });

  group('saving the queue as a playlist', () {
    test('it saves the WHOLE queue, including what already played', () {
      final state = AppState()..attachLibrary(_library(5));
      state.setQueueForTest(_library(5));
      state.playTrackNow('t3');
      expect(state.played, isNotEmpty, reason: 'nothing is in the past, so this proves nothing');

      final made = state.saveQueueAsPlaylist('Morning run');
      expect(made, isNotNull);
      expect(made!.trackIds.length, 5);
      expect(made.trackIds.first, 't0', reason: 'the past was dropped from the saved list');
      expect(state.playlists.byId(made.id), isNotNull, reason: 'the list did not join the collection');
    });

    test('a blank name saves nothing', () {
      final state = AppState()..attachLibrary(_library(5));
      state.setQueueForTest(_library(5));
      expect(state.saveQueueAsPlaylist('   '), isNull);
    });

    test('an empty queue saves nothing', () {
      final state = AppState();
      expect(state.queue, isNull);
      expect(state.saveQueueAsPlaylist('Nope'), isNull);
    });
  });

  group('the prefs round-trip', () {
    test('both new settings survive being written and read back', () {
      const p = AppPrefs(dynamicByDefault: false, refillWhenQueueEnds: true);
      final back = AppPrefs.fromJson(p.toJson());
      expect(back.dynamicByDefault, isFalse);
      expect(back.refillWhenQueueEnds, isTrue);
    });

    test('an old prefs file gets the defaults rather than a wrong mode', () {
      final back = AppPrefs.fromJson({'show_fps': true});
      expect(back.dynamicByDefault, isTrue,
          reason: 'the app would start in FIXED mode for anyone with an existing prefs file');
      expect(back.refillWhenQueueEnds, isFalse);
      expect(back.showFps, isTrue, reason: 'the additive fields disturbed the ones around them');
    });
  });
}
