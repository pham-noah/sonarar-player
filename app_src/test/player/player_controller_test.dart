library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/player_controller.dart';
import 'package:sonarar/player/track_loader.dart';

import 'fake_engine.dart';

Track _t(int n) => Track(
      id: 't$n',
      title: 'Track $n',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
      file: 'music/t$n.m4a',
      cover: '',
      gainDb: 0,
    );

class _Harness {
  _Harness(this.state, this.engine, this.player, this.loader);

  final AppState state;
  final FakeEngine engine;
  final PlayerController player;
  final TrackLoader loader;

  /// What the shell does when the loader says "the file is not there".
  int reloads = 0;
  Duration? reloadStartAt;
  bool reloadAnswer = true;
}

Future<_Harness> _setup({
  int tracks = 4,
  bool enginePresent = true,
  bool skipNextInEngine = false,
  bool skipPreviousInEngine = false,
}) async {
  final library = [for (var i = 0; i < tracks; i++) _t(i)];
  final state = AppState()..attachLibrary(library);
  final repo = LibraryRepository()..root = '/lib';
  await repo.load();

  final engine = FakeEngine()
    ..hasNext = skipNextInEngine
    ..hasPrevious = skipPreviousInEngine;

  late _Harness harness;
  final loader = TrackLoader(
    state: state,
    repo: repo,
    engine: () => enginePresent ? engine : null,
    volume: () => harness.player.volume,
    loopPointsFor: (_) => null,
    exists: (_) => true,
  );

  final player = PlayerController(
    state: state,
    loader: loader,
    engine: () => enginePresent ? engine : null,
    reload: ({Duration? startAt, bool autoPlay = true}) async {
      harness.reloads++;
      harness.reloadStartAt = startAt;
      return harness.reloadAnswer;
    },
  );

  harness = _Harness(state, engine, player, loader);
  return harness;
}

void main() {
  group('the transport', () {
    test('play then pause, and the flag follows', () async {
      final h = await _setup();
      await h.loader.loadCurrent(); // the engine now holds the current track

      await h.player.togglePlay();
      expect(h.player.playing, isTrue);
      expect(h.engine.calls, contains('play'));

      await h.player.togglePlay();
      expect(h.player.playing, isFalse);
      expect(h.engine.calls, contains('pause'));
    });

    test('a track the engine does not hold is loaded, not played', () async {
      final h = await _setup();
      // The loader was never run, so the engine holds nothing.
      await h.player.togglePlay();

      expect(h.reloads, 1, reason: 'a play would have played the wrong thing');
      expect(h.engine.calls, isNot(contains('play')));
      expect(h.player.playing, isTrue, reason: 'the reload answered');
    });

    test('a failed load leaves the transport stopped', () async {
      final h = await _setup();
      h.reloadAnswer = false;

      await h.player.togglePlay();

      expect(h.player.playing, isFalse);
    });

    test('playing at the end of the queue starts that track again', () async {
      final h = await _setup();
      h.state.stopAtEnd();

      await h.player.togglePlay();

      expect(h.reloadStartAt, Duration.zero);
      expect(h.reloads, 1);
    });

    test('nothing happens before the engine exists', () async {
      final h = await _setup(enginePresent: false);

      await h.player.togglePlay();
      await h.player.skipNext();

      expect(h.player.playing, isFalse);
      expect(h.engine.calls, isEmpty);
      expect(h.reloads, 0);
    });

    test('a skip the engine can take stays in the engine', () async {
      final h = await _setup(skipNextInEngine: true);

      await h.player.skipNext();

      expect(h.engine.calls, contains('skipNext'));
      expect(h.reloads, 0, reason: 'the window had room');
    });

    test('at the edge of the window the queue is asked, then reloaded', () async {
      final h = await _setup(skipNextInEngine: false);

      await h.player.skipNext();

      expect(h.engine.calls, isNot(contains('skipNext')));
      expect(h.reloads, 1);
      expect(h.state.currentTrack?.id, 't1');
    });

    test('at the edge with nowhere to go nothing happens', () async {
      final h = await _setup(tracks: 1);

      await h.player.skipNext();

      expect(h.reloads, 0);
      expect(h.engine.calls, isNot(contains('skipNext')));
      expect(h.state.currentTrack?.id, 't0', reason: 'it did not wrap by itself');
    });

    test('a skip clears stop-after-this-track', () async {
      final h = await _setup(skipNextInEngine: true);
      h.player.setStopAfterTrack(true);

      await h.player.skipNext();

      expect(h.player.stopAfterTrack, isFalse,
          reason: 'a skip is a request to move on, not to stop where we land');
    });

    test('volume clamps, remembers the level, and a mute is not a trap', () async {
      final h = await _setup();

      h.player.setVolume(0.4);
      expect(h.player.volume, 0.4);
      expect(h.engine.volume, 0.4);

      h.player.setVolume(2.5);
      expect(h.player.volume, 1.0, reason: 'clamped');

      h.player.setVolume(0.3);
      h.player.toggleMute();
      expect(h.player.volume, 0.0);
      expect(h.player.muted, isTrue);

      h.player.toggleMute();
      expect(h.player.volume, 0.3, reason: 'back to what it was, not to full');
    });

    test('every change notifies the shell once', () async {
      final h = await _setup();
      var notes = 0;
      h.player.addListener(() => notes++);

      h.player.setVolume(0.5);
      h.player.setVolume(0.5);
      h.player.setStopAfterTrack(true);
      h.player.setStopAfterTrack(true);
      h.player.setPlaying(true);
      h.player.setPlaying(true);

      expect(notes, 3, reason: 'a value that did not change must not repaint');
    });

    test('a seek is clamped to the track', () async {
      final h = await _setup();
      h.state.position.value = const Duration(seconds: 10);
      h.state.duration.value = const Duration(seconds: 60);

      await h.player.seekBy(const Duration(seconds: -30));
      expect(h.engine.soughtTo, Duration.zero, reason: 'never before the start');

      await h.player.seekBy(const Duration(seconds: 300));
      expect(h.engine.soughtTo, const Duration(seconds: 60), reason: 'never past the end');
    });
  });
}
