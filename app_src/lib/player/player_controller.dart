/// Who owns the transport: whether it is playing, how loud, and what happens on
/// skip.
///
/// This is the first piece of `_HomeShellState` that had no business being a
/// widget: `_playing` alone was read in twenty-five places and written in ten,
/// with the writes spread over `setState` closures. Anything that reads the flag
/// now reads it here, and anything that changes it says so once — [notifyListeners]
/// is what makes the shell repaint, instead of each call site remembering to.
///
/// It does not load tracks and it does not paint. Loading is [TrackLoader]'s job
/// and painting is the shell's; the one thing this needs from the shell is a way
/// to ask for the current track again after a skip, which arrives as [reload].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/app_state.dart';
import 'playback_engine.dart';
import 'queue.dart' show RepeatMode;
import 'queue_mode.dart' show canStepOutsideEngine;
import 'track_loader.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.state,
    required this.loader,
    required this.engine,
    required this.reload,
  });

  final AppState state;
  final TrackLoader loader;

  /// Null until the audio service has booted; every transport action is a no-op
  /// before then rather than an error.
  final PlaybackEngine? Function() engine;

  /// Loads whatever [state] says is current, and answers whether it played.
  final Future<bool> Function({Duration? startAt, bool autoPlay}) reload;

  bool _playing = false;

  bool get playing => _playing;

  /// Set the flag the transport is judged by. Notification is the point: the
  /// shell repaints from this rather than from a `setState` at each call site.
  void setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    notifyListeners();
  }

  double _volume = 1.0;

  double get volume => _volume;

  double _volumeBeforeMute = 1.0;

  bool get muted => _volume <= 0.0;

  void setVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final changed = clamped != _volume;
    if (clamped > 0) _volumeBeforeMute = clamped;
    _volume = clamped;
    // The engine is told every time (its level can drift from ours), but a slider
    // that reports the level it already has must not repaint the app.
    final e = engine();
    if (e != null) unawaited(e.setVolume(clamped));
    if (changed) notifyListeners();
  }

  void toggleMute() => setVolume(muted ? _volumeBeforeMute : 0.0);

  /// Puts back the level the last session was left at, without touching an engine
  /// that has not booted yet.
  void restoreVolume(double value) {
    final clamped = value.clamp(0.0, 1.0);
    _volume = clamped;
    _volumeBeforeMute = clamped > 0 ? clamped : 1.0;
    notifyListeners();
  }

  bool _stopAfterTrack = false;

  bool get stopAfterTrack => _stopAfterTrack;

  void setStopAfterTrack(bool value) {
    if (_stopAfterTrack == value) return;
    _stopAfterTrack = value;
    notifyListeners();
  }

  /// Guards the platform skip handlers against re-entry: the engine reports the
  /// index change it caused, and that report must not start another skip.
  bool _skipPending = false;

  Future<void> togglePlay() async {
    final e = engine();
    if (e == null) return;

    if (_playing) {
      await e.pause();
      setPlaying(false);
      return;
    }

    if (state.queueEnded) {
      // Parked at the queue's end: play() alone reads as a dead button.
      final id = state.currentTrack?.id;
      if (id != null) state.playTrackNow(id);
      setPlaying(await reload(startAt: Duration.zero));
      return;
    }

    // The engine holds a different track from the one the state points at — the
    // queue moved while paused, or a load failed — so ask for a load, not a play.
    if (!e.isPlaying && loader.loadedTrackId != state.currentTrack?.id) {
      setPlaying(await reload());
      return;
    }

    await e.play();
    setPlaying(true);
  }

  Future<void> skipNext() async {
    final e = engine();
    if (e == null || _skipPending) return;
    // A skip is a request to move on, not to stop where we land.
    setStopAfterTrack(false);
    await _skip(e, forward: true);
  }

  Future<void> skipPrevious() async {
    final e = engine();
    if (e == null || _skipPending) return;
    setStopAfterTrack(false);
    await _skip(e, forward: false);
  }

  Future<void> _skip(PlaybackEngine e, {required bool forward}) async {
    final inEngine = forward ? e.hasNext : e.hasPrevious;

    if (!inEngine) {
      // The engine only holds a window of the queue; at its edge the queue itself
      // decides whether there is anywhere to go.
      if (!canStepOutsideEngine(
        state.queue,
        repeatAll: state.repeatMode == RepeatMode.all,
        forward: forward,
      )) {
        return;
      }
      _skipPending = true;
      try {
        if (forward) {
          state.nextTrack();
        } else {
          state.previousTrack();
        }
        await reload();
      } finally {
        _skipPending = false;
      }
      return;
    }

    _skipPending = true;
    try {
      if (forward) {
        await e.skipNext();
      } else {
        await e.skipPrevious();
      }
    } finally {
      _skipPending = false;
    }
  }

  /// Moves within the current track, clamped to it.
  Future<void> seekBy(Duration delta) async {
    final e = engine();
    if (e == null) return;
    final total = state.duration.value;
    final from = state.position.value;
    var target = from + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (total != null && target > total) target = total;
    await e.seek(target);
  }
}
