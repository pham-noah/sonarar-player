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

List<Track> _lib(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

void main() {
  test('a playlist press names itself as the source', () {
    final state = AppState()..attachLibrary(_lib(5));
    state.setPlaylists(PlaylistList([
      Playlist(id: 'p1', name: 'Late Night Drive', trackIds: const ['t0', 't1']),
    ]));

    expect(state.playingFrom, isNull, reason: 'nothing has built a queue yet');
    final ok = state.playPlaylist(state.playlists.byId('p1')!);
    expect(ok, isTrue);
    expect(state.playingFrom, 'Late Night Drive',
        reason: 'the player would have no source line to show for a queue built FROM a playlist');
  });

  test('pressing a single track CLEARS it — "Playing from Title" is not a source', () {
    final state = AppState()..attachLibrary(_lib(5));
    state.setPlaylists(PlaylistList([
      Playlist(id: 'p1', name: 'Late Night Drive', trackIds: const ['t0', 't1']),
    ]));
    state.playPlaylist(state.playlists.byId('p1')!);
    expect(state.playingFrom, isNotNull, reason: 'fixture is wrong');

    state.playTrack(_t('t3'));
    expect(state.playingFrom, isNull,
        reason: 'a single track inherited the previous playlist name');
  });

  test('the Dynamic row names nothing — it is the app, not a list he made', () {
    final state = AppState()..attachLibrary(_lib(5));
    state.setPlaylists(PlaylistList([
      Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t0', 't1']),
    ]));
    state.updateContext(const PlayContext(
        band: ContextBand.afternoon, sky: Sky.unknown, localHour: 14));

    state.playDynamic();
    expect(state.playingFrom, isNull,
        reason: 'the Dynamic row claimed a source it does not have');
  });
}
