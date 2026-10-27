library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';

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

void main() {
  group('a song press adds to the queue and switches to it', () {
    test('the pressed song becomes current', () {
      final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);
      state.playTrackElsewhere(_t(3));
      expect(state.currentTrack?.id, 't3');
    });

    test('and it does NOT throw away what was already queued', () {
      final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);
      state.playTrackElsewhere(_t(1));
      final afterFirst = state.queue!.order.length;
      expect(afterFirst, greaterThan(0), reason: 'precondition: something is queued');

      state.playTrackElsewhere(_t(4));
      expect(state.queue!.order.any((t) => t.id == 't1'), isTrue,
          reason: 'pressing a second song dropped the first one out of the queue — a song press must ADD');
    });

    test('a song that was NOT already queued still plays', () {
      final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);
      state.playTrackElsewhere(_t(0));

      final stranger = Track(
        id: 'never_queued',
        title: 'Stranger',
        artist: 'Nobody',
        album: 'A',
        duration: const Duration(seconds: 90),
        file: 'x.m4a',
        cover: '',
        gainDb: 0,
      );
      state.attachLibrary([for (var i = 0; i < 6; i++) _t(i), stranger]);
      state.playTrackElsewhere(stranger);
      expect(state.currentTrack?.id, 'never_queued',
          reason: 'a song that was not already queued never started playing — the press did nothing');
    });
  });

  group('a playlist press replaces', () {
    test('the whole queue becomes that list', () {
      final state = AppState()..attachLibrary([for (var i = 0; i < 8; i++) _t(i)]);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'p1', name: 'First', trackIds: const ['t0', 't1']),
        Playlist(id: 'p2', name: 'Second', trackIds: const ['t4', 't5', 't6']),
      ]));

      state.playPlaylist(state.playlists.byId('p1')!);
      expect(state.queue!.order.length, 2);

      state.playPlaylist(state.playlists.byId('p2')!);
      expect(state.queue!.order.length, 3,
          reason: 'the second playlist was ADDED to the first — a playlist press must REPLACE');
      expect(state.queue!.order.any((t) => t.id == 't0'), isFalse,
          reason: 'the first playlist is still in the queue after choosing a second one');
    });
  });
}
