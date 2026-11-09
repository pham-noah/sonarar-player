library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'engine_window.dart';
import 'fade_envelope.dart';
import 'interruption_policy.dart';
import 'queue_edit.dart';
import 'playback_engine.dart';
import 'playback_intent.dart';
import 'transport_state.dart';
import 'volume_policy.dart';

import '../playback/loop_controller.dart';
import '../player/queue.dart' show RepeatMode;

Uri fileUriForPath(String absolutePath) => File(absolutePath).uri;

class AudioEngine implements PlaybackEngine {
  AudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  Future<void> configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _subs.add(session.interruptionEventStream.listen((event) {
      // The rules are a function; this only carries them out.
      switch (interruptionActionFor(
        begin: event.begin,
        type: event.type,
        pausedByInterruption: _pausedByInterruption,
        wantPlay: _transport.wantsPlay,
      )) {
        case InterruptionAction.duck:
          unawaited(_player.setVolume(ducked(_targetVolume)));
        case InterruptionAction.pause:
          _pausedByInterruption = true;
          unawaited(_player.pause());
        case InterruptionAction.restore:
          unawaited(_player.setVolume(restoredLevel(_targetVolume)));
        case InterruptionAction.resume:
          _pausedByInterruption = false;
          notePlayIntent();
          unawaited(_player.play());
        case InterruptionAction.none:
          break;
      }
    }));

    // Headphones out is a pause the platform did not ask for either, so it is
    // remembered the same way: unplugging must not be undone by the next event.

    _subs.add(session.becomingNoisyEventStream.listen((_) {
      _pausedByInterruption = true;
      unawaited(_player.pause());
    }));
  }

  bool _pausedByInterruption = false;

  final AudioPlayer _player;

  VoidCallback? onCompleted;

  @override
  Duration get position => _player.position;

  @override
  bool get isPlaying => _player.playing;

  @override
  Duration? get duration => _player.duration;

  /// What the transport wants; the five flags it replaced are documented there.
  final TransportState _transport = TransportState();

  /// Playing is wanted, but no request is in flight — a queue was handed over, or
  /// an interruption ended.
  void notePlayIntent() => _transport.noteIntent();

  bool _loadFailed = false;

  List<String> get queuePaths => List.unmodifiable(_queuePaths);
  List<String> _queuePaths = const [];

  @override
  Future<void> seekToIndex(int index) => _player.seek(Duration.zero, index: index);

  /// Edits the queue in place: insert, remove and move only what changed.
  ///
  /// [setQueue] hands just_audio a whole new source, which stops the platform
  /// player — the music drops for a moment. A queue edit needs none of that: the
  /// current item is still the current item, so the queue around it can be edited
  /// while it plays.
  @override
  Future<bool> editQueue(List<EngineEntry> items, {required String keepPlaying}) async {
    final source = _player.audioSource;
    if (source is! ConcatenatingAudioSource) return false;
    if (_currentSourcePath() != keepPlaying) return false;

    final edits = queueEditsFor(from: _queuePaths, to: items);
    if (edits.isEmpty) {
      _queuePaths = [for (final i in items) i.path];
      return true;
    }

    try {
      for (final edit in edits) {
        switch (edit) {
          case QueueRemove(:final index):
            await source.removeAt(index);
          case QueueInsert(:final index, :final entry):
            await source.insert(
              index,
              AudioSource.uri(
                fileUriForPath(entry.path),
                tag: MediaItem(
                  id: entry.path,
                  title: entry.title,
                  artist: entry.artist,
                  album: entry.album,
                  artUri: entry.cover,
                ),
              ),
            );
          case QueueMove(:final from, :final to):
            await source.move(from, to);
        }
      }
    } catch (e) {
      // Half-edited is worse than reloaded: say so and let the caller reload.
      debugPrint('[Sonarar][QUEUE] in-place edit failed, reloading: $e');
      return false;
    }

    final kept = _currentSourcePath();
    if (kept != keepPlaying) {
      debugPrint('[Sonarar][QUEUE] in-place edit lost the playing track '
          '(wanted=$keepPlaying, got=$kept), reloading');
      return false;
    }

    _queuePaths = [for (final i in items) i.path];
    // Visible in diagnostics.log: a queue edit that was applied in place. Before
    // this, every edit logged a [LOAD] and the music audibly dropped.
    debugPrint('[Sonarar][QUEUE] edited in place: ${edits.length} op(s) '
        '${edits.take(4).join(", ")}${edits.length > 4 ? " …" : ""}');
    return true;
  }

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

  @override
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

  @override
  Future<bool> setQueue(
    List<EngineEntry> items, {
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
    debugPrint('[Sonarar][LOAD] #$_loadSeq $gap items=${items.length}');

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: want,
        initialPosition: Duration.zero,
      );
    } catch (e, st) {
      if (_superseded(generation)) {
        debugPrint('[Sonarar][LOAD] #$_loadSeq superseded mid-setup, ignored');
        return false;
      }

      _loadFailed = true;
      _queuePaths = const [];
      debugPrint('[Sonarar][LOAD] #$_loadSeq FAILED: $e');
      debugPrint('[Sonarar][AUDIO] stack:\n$st');
      return false;
    }

    _transport.noteIntent();

    if (_superseded(generation)) {
      debugPrint('[Sonarar][LOAD] #$_loadSeq superseded after setup, ignored');
      return false;
    }

    if (_intendedIndex == _player.currentIndex) _intendedIndex = null;
    await _reapplyRepeatMode();

    if (_superseded(generation)) {
      debugPrint('[Sonarar][LOAD] #$_loadSeq superseded during repeat re-assert, ignored');
      return false;
    }

    _wantIndex = want;
    await _player.seek(Duration.zero, index: want);
    return true;
  }

  int? _wantIndex;

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
    if (!await File(absolutePath).exists()) {
      _loadFailed = true;
      debugPrint('[Sonarar][AUDIO] not found: $absolutePath');
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
        _transport.onPlayRequested();
        unawaited(_player.play());
      }
      return true;
    } catch (e) {
      _loadFailed = true;

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
      debugPrint('[Sonarar][AUDIO] load failed: $absolutePath\n'
          '  error: ${e.runtimeType}: $e\n'
          '  probe: $probe');
      return false;
    }
  }

  @override
  Future<void> play() async {
    _transport.onPlayRequested();
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
    } catch (e) {
      debugPrint('[Sonarar][AUDIO] repeat re-assert failed: $e');
    }
  }

  @override
  Future<void> pause() {
    _transport.onPauseRequested();
    return _player.pause();
  }

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
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

  /// The fade lives in its own object now; it only needs to set and read the
  /// engine's level, which is all the two callbacks are.
  late final FadeEnvelope _fade = FadeEnvelope(
    applyVolume: (v) {
      // The fade is fire-and-forget; the engine reports its own failures.
      unawaited(_player.setVolume(v));
    },
    readVolume: () => _player.volume,
  );

  void _cancelFade() => _fade.cancel();

  Future<void> _fadeTo(double to, Duration over) => _fade.fadeTo(to, over);

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

  @override
  Future<void> skipNext() {
    _transport.onSkipRequested();
    return _player.seekToNext();
  }

  @override
  Future<void> skipPrevious() {
    _transport.onSkipRequested();
    return _player.seekToPrevious();
  }

  @override
  bool get hasNext => _player.hasNext;
  @override
  bool get hasPrevious => _player.hasPrevious;

  Future<void> stop() => _player.stop();

  void Function(bool playing)? onPlayingChanged;

  void Function(String path)? onSourceChanged;

  String? _currentSourcePath() {
    final tag = _player.sequenceState?.currentSource?.tag;
    if (tag is MediaItem) return tag.id;
    return null;
  }

  @override
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

      debugPrint('[Sonarar][SKIP] index=$index intended=$intended '
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

        _transport.onSourceChanged(
          platformMoved: true,
          platformPlaying: st.playing,
          platformCompleted: st.processingState == ProcessingState.completed,
        );

        _wantIndex = index;
      }

      onSourceChanged?.call(path);
    }));

    _subs.add(_player.playerStateStream.listen((state) {
      if (state.playing != _lastReportedPlaying) {
        _lastReportedPlaying = state.playing;
        onPlayingChanged?.call(state.playing);
      }
      if (state.processingState == ProcessingState.completed) {
        if (!_transport.onCompletedEvent(loadFailed: _loadFailed)) return;
        onCompleted?.call();
        return;
      }

      final action = _transport.actionFor(
        playing: state.playing,
        loading: state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering,
      );
      _transport.apply(action);
      if (action == PlayAction.reissuePlay) unawaited(_player.play());

      final want = _wantIndex;
      if (want != null &&
          state.processingState == ProcessingState.ready &&
          _player.currentIndex != want) {
        unawaited(_player.seek(Duration.zero, index: want));
      }
    }));
  }

  @override
  LoopController? loop;

  Future<void> _fadeThenStop() async {
    _transport.stopRequested();

    // The loop's own fade length, or 400 ms when it has none, on the same fade
    // path as everything else so cancelling behaves the same way.
    final over = Duration(
      milliseconds: loop?.points?.fade.inMilliseconds != null
          ? loop!.points!.fade.inMilliseconds.clamp(50, 2000)
          : 400,
    );
    await _fade.fadeTo(0, over);
    await _player.pause();
    try {
      await _player.setVolume(restoredLevel(_targetVolume));
    } catch (e) {
      debugPrint('[Sonarar][AUDIO] volume restore failed: $e');
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
        if (_transport.wantsPlay) await _fadeThenStop();
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
