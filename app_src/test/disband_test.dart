library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
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
  test('disband clears the TRACK, not just the queue — so the mini player hides', () {
    final state = AppState()..attachLibrary([for (var i = 0; i < 5; i++) _t(i)]);
    state.playTrack(_t(2));
    expect(state.currentTrack, isNotNull, reason: 'precondition: something is playing');
    expect(state.queue, isNotNull);

    final ok = state.disbandQueue();
    expect(ok, isTrue);

    expect(state.currentTrack, isNull,
        reason: 'a track is still current after disbanding — the mini player will stay on screen and the '
            'press will look like it did nothing, which is the reported bug');
    expect(state.queue, isNull, reason: 'the queue survived the disband');
  });

  test('disband with nothing playing is a no-op, not a crash', () {
    final state = AppState();
    expect(state.currentTrack, isNull, reason: 'precondition: nothing is loaded');
    expect(state.disbandQueue(), isFalse);
  });

  test('and playing again afterwards still works', () {
    final state = AppState()..attachLibrary([for (var i = 0; i < 5; i++) _t(i)]);
    state.playTrack(_t(1));
    state.disbandQueue();
    expect(state.currentTrack, isNull);

    state.playTrack(_t(3));
    expect(state.currentTrack?.id, 't3',
        reason: 'the app could not play anything after a disband');
  });
}
