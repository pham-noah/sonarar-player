library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/dynamic_playlist.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/library/playlists.dart';

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
  state.attachLibrary(List.generate(24, (i) => _t('t$i')));
  state.setPlaylists(PlaylistList([
    Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t0', 't1']),
    Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t20', 't21']),
  ]));

  state.updateContext(
    const PlayContext(
      band: ContextBand.afternoon,
      sky: Sky.unknown,
      localHour: 14));
  return state;
}

void main() {
  group('the situation rules are not gated on the queue being live', () {
    test('ARMING works while a plain playlist is playing', () {
      final state = _booted();
      state.playPlaylistRef('p3r');
      state.setSleeping(true);

      expect(state.sleeping, isTrue);
      expect(state.source, isNot(null));
    });

    test('DISARMING is also not gated', () {
      final state = _booted();
      state.playPlaylistRef('p3r');
      state.setSleeping(true);
      state.setSleeping(false);
      expect(state.sleeping, isFalse);
    });

    test('the override appends rather than replacing', () {
      final state = _booted();
      state.playPlaylistRef('p3r');
      final before = state.currentTrack?.id;
      state.playTrackNow(before!);
      state.setSleeping(true);
      expect(state.currentTrack?.id, before,
          reason: 'arming the sleep timer changed the track that was playing');
    });
  });

  group('the Dynamic row follows the context', () {
    test('the mix is rebuilt when the context changes', () {
      final state = _booted();

      final first = state.dynamicMix();
      expect(first, isNotNull, reason: 'no mix at all — the fixture is wrong');
      state.setDerivedPlaylists([first!]);

      final derivedBefore = state.derivedPlaylists
          .firstWhere((p) => p.id == kDynamicId)
          .trackIds
          .toList();

      state.updateContext(
        const PlayContext(
          band: ContextBand.darkHour,
          sky: Sky.unknown,
          localHour: 2));
      state.updateContext(
        const PlayContext(
          band: ContextBand.morning,
          sky: Sky.unknown,
          localHour: 8));

      final derivedAfter = state.derivedPlaylists
          .firstWhere((p) => p.id == kDynamicId)
          .trackIds
          .toList();

      final live = state.dynamicMix();
      expect(derivedAfter, live!.trackIds,
          reason: 'the Dynamic row is serving a snapshot, not the current mix');
      expect(derivedBefore, isNotEmpty);
    });

    test('there is exactly one Dynamic row', () {
      final state = _booted();
      final mix = state.dynamicMix()!;
      state.setDerivedPlaylists([mix]);
      state.setSleeping(true);
      final rows = state.derivedPlaylists.where((p) => p.id == kDynamicId);
      expect(rows.length, 1, reason: 'the Dynamic row was duplicated or lost');
    });
  });
}
