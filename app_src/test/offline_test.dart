library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

AppState _booted() {
  final state = AppState();
  state.attachLibrary([for (var i = 0; i < 12; i++) _t('t$i')]);
  state.setPlaylists(PlaylistList([
    Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t0', 't1']),
    Playlist(id: 'uni', name: 'Uni', trackIds: const ['t2']),
    Playlist(id: 'my_custom', name: 'My Own Thing', trackIds: const ['t3']),
  ]));
  state.updateContext(const PlayContext(
      band: ContextBand.afternoon, sky: Sky.unknown, localHour: 14));
  return state;
}

void main() {
  group('the mix is the context, and offline removes the context', () {
    test('the band list LEADS while the context is on', () {
      final state = _booted();
      final mix = state.dynamicMix();
      expect(mix, isNotNull);
      expect(mix!.trackIds, contains('t0'),
          reason: 'the afternoon list should feed the afternoon mix');
    });

    test('offline empties the mix ENTIRELY, not partly', () {
      final state = _booted();
      expect(state.dynamicMix(), isNotNull, reason: 'fixture is wrong');
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: false);

      expect(state.dynamicMix(), isNull,
          reason: 'the context still chose music with offline set');
    });

    test('turning offline back ON restores the mix', () {
      final state = _booted();
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: false);
      expect(state.dynamicMix(), isNull);
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: true);
      expect(state.dynamicMix(), isNotNull,
          reason: 'the switch must be reversible — it is a view, not a delete');
    });
  });

  group('the fourteen context lists leave the UI, the rest stay', () {
    test('offline hides them', () {
      final state = _booted();
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: false);
      final ids = state.visiblePlaylists.map((p) => p.id).toSet();
      expect(ids, isNot(contains('v_afternoon')));
      expect(ids, isNot(contains('uni')));
      expect(ids, contains('my_custom'));
    });

    test('the lists are still THERE — hidden, not deleted', () {
      final state = _booted();
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: false);

      expect(state.allPlaylists.map((p) => p.id), contains('v_afternoon'));
      expect(state.allPlaylists.map((p) => p.id), contains('uni'));
    });

    test('on, everything shows again', () {
      final state = _booted();
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: false);
      state.applyQueuePrefs(
          defaultMode: false, refill: false, contextEnabled: true);
      expect(state.visiblePlaylists.length, state.allPlaylists.length);
    });
  });
}
