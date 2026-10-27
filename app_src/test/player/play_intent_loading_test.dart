library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/playback_intent.dart';

void main() {
  group('a play call during LOADING is awaited, not retried', () {
    test('loading + outstanding is not a dropped call', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: true,
          retries: 0,
          completed: false,
          loading: true,
        ),
        PlayAction.none,
        reason: 'nothing to start yet, so there is nothing to rescue',
      );
    });

    test('the retry budget survives a long load', () {
      var retries = 0;
      for (var i = 0; i < 12; i++) {
        final a = nextPlayAction(
          playing: false,
          outstanding: true,
          retries: retries,
          completed: false,
          loading: true,
        );
        if (a == PlayAction.reissuePlay) retries++;
      }
      expect(retries, 0, reason: 'no retry may be spent while loading');
    });

    test('once ready and still not playing, the rescue still works', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: true,
          retries: 0,
          completed: false,
          loading: false,
        ),
        PlayAction.reissuePlay,
      );
    });

    test('a notification pause while loading is still adopted', () {
      expect(
        nextPlayAction(
          playing: false,
          outstanding: false,
          retries: 0,
          completed: false,
          loading: false,
        ),
        PlayAction.adoptStopped,
      );
    });
  });
}
