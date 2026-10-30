library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'playback_intent.dart';
import 'volume_policy.dart';

import '../playback/loop_controller.dart';
import '../player/queue.dart' show RepeatMode;

Uri fileUriForPath(String absolutePath) => File(absolutePath).uri;

class AudioEngine {
  AudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  Future<void> configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _subs.add(session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:

            unawaited(_player.setVolume(ducked(_targetVolume)));
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:

            _pausedByInterruption = true;
            unawaited(_player.pause());
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:

            unawaited(_player.setVolume(restoredLevel(_targetVolume)));
          case AudioInterruptionType.pause:

            if (_pausedByInterruption && _wantPlay) {
              _pausedByInterruption = false;
              notePlayIntent();
              unawaited(_player.play());
            }
          case AudioInterruptionType.unknown:
            break;
        }
      }
    }));

    _subs.add(session.becomingNoisyEventStream.listen((_) {
      _pausedByInterruption = true;
      unawaited(_player.pause());
    }));
  }

  bool _pausedByInterruption = false;

  final AudioPlayer _player;

  VoidCallback? onCompleted;

  Duration get position => _player.position;

  bool get isPlaying => _player.playing;

  Duration? get duration => _player.duration;

  bool _wantPlay = false;

  bool _playOutstanding = false;

  int _playRetries = 0;

  bool _suppressNextCompletion = false;

  void notePlayIntent() {
    _wantPlay = true;
  }

  bool _loadFailed = false;

  List<String> get queuePaths => List.unmodifiable(_queuePaths);
  List<String> _queuePaths = const [];

  Future<void> seekToIndex(int index) => _player.seek(Duration.zero, index: index);

  bool moveWithinEngine(int from, int to) {
    final source = _player.audioSource;
    if (source is! ConcatenatingAudioSource) return false;
    if (from < 0 || to < 0) return false;
    if (from >= source.length || to >= source.length) return false;
    if (from == to) return true;

    unawaited(source.move(from, to));
    final moved = _queuePaths.removeAt(from);
    _queuePaths.insert(to, moved);
    return true;
  }

  bool queueMatches(List<String> paths) {
    if (paths.length != _queuePaths.length) return false;
    for (var i = 0; i < paths.length; i++) {
      if (paths[i] != _queuePaths[i]) return false;
    }
    return true;
  }

  int _loadGeneration = 0;

  bool _superseded(int generation) => generation != _loadGeneration;

  static int _loadSeq = 0;
  DateTime? _lastLoadAt;

  Future<bool> setQueue(
    List<({String path, String title, String artist, String album, Uri? cover})> items, {
    required int initialIndex,
  }) async {
    final sources = <AudioSource>[
      for (final i in items)
        AudioSource.uri(
          fileUriForPath(i.path),
          tag: MediaItem(
            id: i.path,
            title: i.title,
            artist: i.artist,
            album: i.album,
            artUri: i.cover,

          ),
        ),
    ];

    if (sources.isEmpty) return false;
    final want = initialIndex.clamp(0, sources.length - 1);

    _intendedIndex = want;
    _queuePaths = [for (final i in items) i.path];

    _loadSeq++;
    final generation = ++_loadGeneration;
    final now = DateTime.now();
    final gap = _lastLoadAt == null
        ? 'first'
        : '${now.difference(_lastLoadAt!).inMilliseconds}ms since #${_loadSeq - 1}';
    _lastLoadAt = now;
    // ignore: avoid_print
    print('[Sonarar][LOAD] #$_loadSeq $gap items=${items.length}');

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: want,
        initialPosition: Duration.zero,
      );
    } catch (e, st) {
      if (_superseded(generation)) {
        // ignore: avoid_print
        print('[Sonarar][LOAD] #$_loadSeq superseded mid-setup, ignored');
        return false;
      }

      _loadFailed = true;
      _queuePaths = const [];
      // ignore: avoid_print
      print('[Sonarar][LOAD] #$_loadSeq FAILED: $e');
      // ignore: avoid_print
      print('[Sonarar][AUDIO] stack:\n$st');
      return false;
    }

    _wantPlay = true;

    notePlayIntent();

    if (_superseded(generation)) {
      // ignore: avoid_print
      print('[Sonarar][LOAD] #$_loadSeq superseded after setup, ignored');
      return false;
    }

    if (_intendedIndex == _player.currentIndex) _intendedIndex = null;
    await _reapplyRepeatMode();

    if (_superseded(generation)) {
      // ignore: avoid_print
      print('[Sonarar][LOAD] #$_loadSeq superseded during repeat re-assert, ignored');
      return false;
    }

    _wantIndex = want;
    await _player.seek(Duration.zero, index: want);
    return true;
  }

  int? _wantIndex;

  Future<bool> loadAndPlay(
    String absolutePath, {
    Duration? startAt,
    bool autoPlay = true,

    String title = '',
    String artist = '',
    String album = '',
    Uri? coverUri,
  }) async {
    if (!await File(absolutePath).exists()) {
      _loadFailed = true;
      // ignore: avoid_print
      print('[Sonarar][AUDIO] not found: $absolutePath');
      return false;
    }
    try {
      _loadFailed = false;

      _queuePaths = const [];
      _loadGeneration++;

      _wantIndex = null;

      final uri = fileUriForPath(absolutePath);

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: absolutePath,
            title: title,
            artist: artist,
            album: album,

            artUri: coverUri,
          ),
        ),
      );
      if (startAt != null && startAt > Duration.zero) {
        await _player.seek(startAt);
      }

      if (autoPlay) {
        _wantPlay = true;
        _playOutstanding = true;
        _playRetries = 0;
        unawaited(_player.play());
      }
      return true;
    } catch (e) {
      _loadFailed = true;
      // ignore: avoid_print

      String probe;
      try {
        final f = File(absolutePath);
        if (!f.existsSync()) {
          probe = 'file does not exist';
        } else {
          final raf = f.openSync();
          probe = 'readable (${raf.lengthSync()} bytes)';
          raf.closeSync();
        }
      } catch (e) {
        probe = 'NOT READABLE: ${e.runtimeType}: $e';
      }
      // ignore: avoid_print
      print('[Sonarar][AUDIO] load failed: $absolutePath\n'
          '  error: ${e.runtimeType}: $e\n'
          '  probe: $probe');
      return false;
    }
  }

  Future<void> play() async {
    _wantPlay = true;
    _playOutstanding = true;
    _playRetries = 0;
    // ignore: discarded_futures
    unawaited(_player.play());
  }

  RepeatMode _appRepeat = RepeatMode.off;

  Future<void> _reapplyRepeatMode() => setRepeatMode(_appRepeat);

  Future<void> setRepeatMode(RepeatMode mode) async {
    _appRepeat = mode;
    try {
      // Engine loop never reports completion, so repeats went uncounted.
      await _player.setLoopMode(LoopMode.off);
    } catch (_) {
    }
  }

  Future<void> pause() {
    _wantPlay = false;
    _playOutstanding = false;
    _playRetries = 0;
    return _player.pause();
  }

  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> setVolume(double v) {
    _cancelFade();
    _targetVolume = v.clamp(0.0, 1.0);
    return _player.setVolume(_targetVolume);
  }

  double _targetVolume = 1.0;

  Duration _crossfade = Duration.zero;
  Duration get crossfade => _crossfade;
  bool get crossfadeEnabled => _crossfade > Duration.zero;

  void setCrossfade(Duration d) {
    _crossfade = d < Duration.zero
        ? Duration.zero
        : (d > const Duration(seconds: 12) ? const Duration(seconds: 12) : d);
  }

  Timer? _fadeTimer;

  Completer<void>? _fadeDone;

  bool _fadingOut = false;

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
    _fadingOut = false;
    final done = _fadeDone;
    _fadeDone = null;

    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _fadeTo(double to, Duration over) async {
    _cancelFade();
    if (over <= Duration.zero) {
      await _player.setVolume(to.clamp(0.0, 1.0));
      return;
    }
    const steps = 24;
    final from = _player.volume;
    final step = over.inMilliseconds ~/ steps;
    var i = 0;
    final done = Completer<void>();
    _fadeDone = done;
    _fadeTimer = Timer.periodic(Duration(milliseconds: step.clamp(8, 500)), (t) {
      i++;
      final f = (i / steps).clamp(0.0, 1.0);
      // ignore: discarded_futures
      _player.setVolume((from + (to - from) * f).clamp(0.0, 1.0));
      if (i >= steps) {
        t.cancel();
        _fadeTimer = null;
        _fadeDone = null;
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }

  Future<Duration?> beginVariantSwap() async {
    if (_variantSwapPosition != null) return _variantSwapPosition;
    _variantSwapPosition = _player.position;
    _variantSwapWasPlaying = _player.playing;

    await _fadeTo(0, const Duration(milliseconds: 140));
    return _variantSwapPosition;
  }

  Future<void> completeVariantSwap({Duration? fallbackAt}) async {
    final at = _variantSwapPosition ?? fallbackAt;
    if (at != null) await _player.seek(at);
    if (_variantSwapWasPlaying) {
      await _player.play();
    }
    await _fadeTo(_targetVolume, const Duration(milliseconds: 200));
    _variantSwapPosition = null;
    _variantSwapWasPlaying = false;
  }

  Future<void> abortVariantSwap() async {
    _variantSwapPosition = null;
    _variantSwapWasPlaying = false;
    await _fadeTo(_targetVolume, const Duration(milliseconds: 200));
  }

  Duration? _variantSwapPosition;
  bool _variantSwapWasPlaying = false;

  Future<void> skipNext() {
    _skipRequested = true;
    return _player.seekToNext();
  }

  Future<void> skipPrevious() {
    _skipRequested = true;
    return _player.seekToPrevious();
  }

  bool _skipRequested = false;

  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  Future<void> stop() => _player.stop();

  void Function(bool playing)? onPlayingChanged;

  void Function(String path)? onSourceChanged;

  String? _currentSourcePath() {
    final tag = _player.sequenceState?.currentSource?.tag;
    if (tag is MediaItem) return tag.id;
    return null;
  }

  String? get playingPath => _currentSourcePath();

  String? _lastReportedPath;

  bool _lastReportedPlaying = false;

  int? _intendedIndex;

  bool get sourceChangeWasPlatformInitiated => _sourceChangeWasPlatformInitiated;
  bool _sourceChangeWasPlatformInitiated = false;

  void clearPlatformSourceChange() => _sourceChangeWasPlatformInitiated = false;

  void listen() {
    _subs.add(_player.currentIndexStream.listen((index) {
      final path = _currentSourcePath();
      if (path == null) return;

      final intended = _intendedIndex;
      _intendedIndex = null;

      // ignore: avoid_print
      print('[Sonarar][SKIP] index=$index intended=$intended '
          'same_path=${path == _lastReportedPath} playing=${_player.playing}');

      if (path == _lastReportedPath) return;
      _lastReportedPath = path;

      final platformMoved = intended == null || intended != index;

      if (crossfadeEnabled) {
        // ignore: discarded_futures
        _fadeTo(_targetVolume, _crossfade);
      }

      _sourceChangeWasPlatformInitiated = platformMoved;

      if (platformMoved) {
        final st = _player.playerState;

        if (_skipRequested) {
          _wantPlay = true;
          _skipRequested = false;
        } else if (st.processingState != ProcessingState.completed) {
          _wantPlay = st.playing;
        }

        _wantIndex = index;

        _suppressNextCompletion = true;
      }

      onSourceChanged?.call(path);
    }));

    _subs.add(_player.playerStateStream.listen((state) {
      if (state.playing != _lastReportedPlaying) {
        _lastReportedPlaying = state.playing;
        onPlayingChanged?.call(state.playing);
      }
      if (state.processingState == ProcessingState.completed) {
        if (!shouldReportCompletion(
          loadFailed: _loadFailed,
          suppressNext: _suppressNextCompletion,
        )) {
          _suppressNextCompletion = false;
          if (_loadFailed) _wantPlay = false;
          return;
        }
        _suppressNextCompletion = false;
        onCompleted?.call();
        _wantPlay = false;
        return;
      }

      switch (nextPlayAction(
        playing: state.playing,
        outstanding: _playOutstanding,
        retries: _playRetries,
        completed: false,

        loading: state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering,
      )) {
        case PlayAction.reissuePlay:
          _playRetries++;
          unawaited(_player.play());
        case PlayAction.giveUp:

          _playOutstanding = false;
          _wantPlay = false;
        case PlayAction.adoptPlaying:
          _playOutstanding = false;
          _playRetries = 0;
        case PlayAction.adoptStopped:

          _wantPlay = false;
        case PlayAction.none:
          break;
      }

      final want = _wantIndex;
      if (want != null &&
          state.processingState == ProcessingState.ready &&
          _player.currentIndex != want) {
        unawaited(_player.seek(Duration.zero, index: want));
      }
    }));
  }

  LoopController? loop;

  Future<void> _fadeThenStop() async {
    _wantPlay = false;

    _fadingOut = true;
    const steps = 20;
    final gap = Duration(milliseconds: loop?.points?.fade.inMilliseconds != null
        ? (loop!.points!.fade.inMilliseconds / steps).round().clamp(50, 2000)
        : 400);

    final from = _player.volume;
    for (var i = steps; i >= 0; i--) {
      if (!_fadingOut) break;
      try {
        await _player.setVolume((from * (i / steps)).clamp(0.0, 1.0));
      } catch (_) {
        break;
      }
      await Future<void>.delayed(gap);
    }
    _fadingOut = false;
    await _player.pause();
    try {
      await _player.setVolume(restoredLevel(_targetVolume));
    } catch (_) {
    }
  }

  Future<void> tickLoop() async {
    final c = loop;
    if (c == null || !c.hasLoop) return;

    final dur = duration;
    if (dur == null || dur <= Duration.zero) return;

    switch (c.decide(position: position, duration: dur)) {
      case LoopAction.seekToLoopStart:
        await seek(c.points!.loopStart!);
      case LoopAction.fadeOut:
        if (_wantPlay) await _fadeThenStop();
      case LoopAction.none:
        break;
    }
  }

  final List<StreamSubscription<dynamic>> _subs = [];

  Future<void> dispose() async {
    _cancelFade();
    for (final s in _subs) {
      // ignore: discarded_futures
      unawaited(s.cancel());
    }
    _subs.clear();
    await _player.dispose();
  }
}
