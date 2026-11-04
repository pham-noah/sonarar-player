library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/playback/loop_controller.dart';
import 'package:sonarar/player/engine_window.dart';
import 'package:sonarar/player/playback_engine.dart';
import 'package:sonarar/player/track_loader.dart';

Track _t(int n) => Track(
      id: 't$n',
      title: 'Track $n',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
      file: 'music/t$n.m4a',
      cover: 'covers/t$n.jpg',
      gainDb: 0,
    );

/// Records what the loader asked for, and answers what the test scripts.
class FakeEngine implements PlaybackEngine {
  final List<String> calls = [];

  List<EngineEntry>? queued;
  int? queuedIndex;
  String? singlePath;
  Duration? soughtTo;
  int? soughtIndex;
  double volume = 1;

  bool setQueueAnswer = true;
  bool loadAnswer = true;
  bool matchesAnswer = false;

  final Duration _position = Duration.zero;
  bool _playing = false;
  String? _path;
  LoopController? _loop;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => null;

  @override
  bool get isPlaying => _playing;

  @override
  String? get playingPath => _path;

  @override
  LoopController? get loop => _loop;

  @override
  set loop(LoopController? value) {
    _loop = value;
    calls.add('loop');
  }

  @override
  bool queueMatches(List<String> paths) {
    calls.add('queueMatches');
    return matchesAnswer;
  }

  @override
  Future<bool> setQueue(List<EngineEntry> items, {required int initialIndex}) async {
    calls.add('setQueue');
    queued = items;
    queuedIndex = initialIndex;
    return setQueueAnswer;
  }

  @override
  Future<bool> loadAndPlay(
    String absolutePath, {
    Duration? startAt,
    bool autoPlay = true,
    String title = '',
    String artist = '',
    String album = '',
    Uri? coverUri,
  }) async {
    calls.add('loadAndPlay');
    singlePath = absolutePath;
    return loadAnswer;
  }

  @override
  Future<void> seekToIndex(int index) async {
    calls.add('seekToIndex');
    soughtIndex = index;
  }

  @override
  Future<void> seek(Duration to) async {
    calls.add('seek');
    soughtTo = to;
  }

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
  }

  @override
  Future<void> setVolume(double value) async {
    calls.add('setVolume');
    volume = value;
  }
}

class _Harness {
  _Harness(this.state, this.repo, this.engine, this.loader);

  final AppState state;
  final LibraryRepository repo;
  final FakeEngine engine;
  final TrackLoader loader;
}

Future<_Harness> _setup({
  int tracks = 4,
  Set<String>? exists,
  bool enginePresent = true,
  double volume = 0.6,
}) async {
  final library = [for (var i = 0; i < tracks; i++) _t(i)];
  final state = AppState()..attachLibrary(library);
  final repo = LibraryRepository()..root = '/lib';
  await repo.load();

  final engine = FakeEngine();
  final loader = TrackLoader(
    state: state,
    repo: repo,
    engine: () => enginePresent ? engine : null,
    volume: () => volume,
    loopPointsFor: (_) => null,
    exists: (p) => exists == null ? true : exists.contains(p),
  );
  return _Harness(state, repo, engine, loader);
}

void main() {
  group('loading the current track', () {
    test('does nothing, quietly, before the engine exists', () async {
      final h = await _setup(enginePresent: false);

      expect(await h.loader.loadCurrent(), isFalse);
      expect(h.engine.calls, isEmpty);
      expect(h.loader.fileMissing, isFalse,
          reason: 'a player that has not booted has not failed');
    });

    test('does nothing when there is nothing to play', () async {
      final state = AppState();
      final repo = LibraryRepository()..root = '/lib';
      await repo.load();
      final engine = FakeEngine();
      final loader = TrackLoader(
        state: state,
        repo: repo,
        engine: () => engine,
        volume: () => 1,
        loopPointsFor: (_) => null,
        exists: (_) => true,
      );

      expect(await loader.loadCurrent(), isFalse);
      expect(engine.calls, isEmpty);
    });

    test('restores the volume the load resets', () async {
      final h = await _setup(volume: 0.42);

      await h.loader.loadCurrent();

      expect(h.engine.volume, 0.42);
    });

    test('sets the queue around the current track and marks the engine synced',
        () async {
      final h = await _setup(tracks: 4);

      final ok = await h.loader.loadCurrent();

      expect(ok, isTrue);
      expect(h.engine.calls, contains('setQueue'));
      expect(h.engine.queued, hasLength(4));
      expect(h.engine.queuedIndex, 0, reason: 't0 is the first of the window');
      expect(h.state.queue!.engineIsStale, isFalse);
      expect(h.loader.fileMissing, isFalse);
      expect(h.loader.loadedTrackId, 't0');
    });

    test('seeks inside a queue the engine already holds instead of resetting it',
        () async {
      final h = await _setup(tracks: 4);
      h.engine.matchesAnswer = true;
      h.state.queue!.markEngineSynced();

      final ok = await h.loader.loadCurrent();

      expect(ok, isTrue);
      expect(h.engine.calls, isNot(contains('setQueue')));
      expect(h.engine.calls, contains('seekToIndex'));
      expect(h.engine.calls, contains('play'), reason: 'it was not playing');
    });

    test('a resume position is seeked to after the queue is set', () async {
      final h = await _setup(tracks: 4);

      await h.loader.loadCurrent(startAt: const Duration(seconds: 42));

      expect(h.engine.soughtTo, const Duration(seconds: 42));
      final seekAt = h.engine.calls.indexOf('seek');
      final setAt = h.engine.calls.indexOf('setQueue');
      expect(seekAt, greaterThan(setAt));
    });

    test('a track whose own file is missing plays on its own', () async {
      final h = await _setup(
        tracks: 4,
        exists: {'/lib/music/t0.m4a'},
      );
      // Move the queue onto a track whose file is not there.
      h.state.queue!.jumpTo('t2');

      final ok = await h.loader.loadCurrent();

      expect(ok, isTrue);
      expect(h.engine.calls, contains('loadAndPlay'));
      expect(h.engine.singlePath, '/lib/music/t2.m4a');
      expect(h.loader.fileMissing, isFalse);
    });

    test('nothing playable at all reports the file missing and keeps the queue',
        () async {
      final h = await _setup(tracks: 4, exists: {});

      final ok = await h.loader.loadCurrent();

      expect(ok, isFalse);
      expect(h.loader.fileMissing, isTrue);
      expect(h.engine.calls, isNot(contains('setQueue')),
          reason: 'the queue it holds is better than an empty one');
    });

    test('an engine refusal is reported, not thrown', () async {
      final h = await _setup(tracks: 4);
      h.engine.setQueueAnswer = false;

      final ok = await h.loader.loadCurrent();

      expect(ok, isFalse);
      expect(h.loader.fileMissing, isTrue);
      expect(h.loader.loadedTrackId, isNull);
    });
  });
}
