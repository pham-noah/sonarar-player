import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'a',
      album: 'b',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

List<Track> _lib(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

void main() {
  group('a library that arrives while something is playing', () {
    test('keeps the queue and the current track', () {
      final state = AppState()..attachLibrary(_lib(4));
      state.playTrackNow('t2');
      expect(state.currentTrack!.id, 't2');
      final before = state.queue!.orderVersion;

      state.attachLibrary(_lib(6));

      expect(state.library.length, 6);
      expect(state.currentTrack!.id, 't2',
          reason: 'a refresh must never change what is playing');
      expect(state.queueOrder.map((t) => t.id).toList(),
          ['t0', 't1', 't2', 't3', 't4', 't5']);
      expect(state.queue!.orderVersion, greaterThan(before),
          reason: 'the engine still has to be told to re-sync');
    });

    test('does not restart the queue at its first track', () {
      final state = AppState()..attachLibrary(_lib(5));
      state.playTrackNow('t4');

      state.attachLibrary(_lib(5));

      expect(state.queueIndex, 4);
    });

    test('keeps a track that the new manifest no longer lists', () {
      final state = AppState()..attachLibrary(_lib(4));
      state.playTrackNow('t3');

      state.attachLibrary(_lib(3));

      expect(state.currentTrack!.id, 't3',
          reason: 'losing the file is the loader\'s problem, not a reason to jump');
      expect(state.queueOrder.any((t) => t.id == 't3'), isTrue);
    });

    test('the FIRST attach starts at the top of the library', () {
      final state = AppState()..attachLibrary(_lib(4));
      expect(state.currentTrack!.id, 't0');
      expect(state.queueOrder.length, 4);
    });
  });
}
