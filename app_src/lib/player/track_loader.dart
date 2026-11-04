/// Puts the current track into the engine, and says whether it got there.
///
/// This is the part of the shell that used to be `_loadCurrentTrack`: resolve the
/// file, hand the engine the window of the queue around it, and pick the right
/// one of the engine's three ways in (seek inside the queue it already holds, set
/// a new queue, or play a single file that is not in the window).
///
/// What it deliberately does **not** do is decide what the interface shows or what
/// to play after a failure — stepping over an unloadable track is a UI decision,
/// so it stays in the shell. That split is what lets the loading rules be tested
/// against a fake engine instead of a widget tree.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;

import '../core/app_state.dart';
import '../library/library_repository.dart';
import '../library/track.dart';
import '../playback/loop_controller.dart';
import '../playback/loop_points.dart';
import 'engine_window.dart';
import 'playback_engine.dart';

class TrackLoader {
  TrackLoader({
    required this.state,
    required this.repo,
    required this.engine,
    required this.volume,
    required this.loopPointsFor,
    bool Function(String path)? exists,
  }) : _exists = exists ?? _fileExists;

  final AppState state;
  final LibraryRepository repo;

  /// Null until the engine has booted; loading before then is a no-op, not an error.
  final PlaybackEngine? Function() engine;

  /// The level to restore after the engine loads, since loading resets it.
  final double Function() volume;

  final LoopPoints? Function(String trackId) loopPointsFor;

  /// Injected so the window can be built against a pretend disk in tests.
  final bool Function(String path) _exists;

  static bool _fileExists(String path) => File(path).existsSync();

  bool _fileMissing = false;

  /// True when the last attempt could not put anything into the engine.
  bool get fileMissing => _fileMissing;

  String? _loadedTrackId;

  /// The id of the track the engine was last given, when it took it.
  String? get loadedTrackId => _loadedTrackId;

  /// Loads whatever [state] says is current.
  ///
  /// Returns false when there was nothing to load or the engine refused it; the
  /// caller decides whether that is a skip, a toast or a retry.
  Future<bool> loadCurrent({Duration? startAt, bool autoPlay = true}) async {
    final e = engine();
    final track = state.currentTrack;
    if (e == null || track == null) return false;
    final path = repo.absoluteFor(track);
    if (path == null) return false;

    e.loop = LoopController(points: loopPointsFor(track.id));

    final effectiveStart = startAt ?? Duration.zero;

    // Loading resets the engine's volume, so the level is put back with it.
    unawaited(e.setVolume(volume()));

    final order = state.queue?.order ?? const <Track>[];

    if (order.length < 3) {
      debugPrint('[Sonarar][SHORTQUEUE] order=${order.length} track=${track.id} '
          'want=${state.currentTrack?.id}');
      debugPrint('[Sonarar][SHORTQUEUE] stack:\n${StackTrace.current}');
    }

    final built = engineWindowFor(
      order: order,
      track: track,
      pathFor: repo.absoluteFor,
      coverFor: repo.coverPathFor,
      exists: _exists,
    );
    final playable = built.entries;
    final idx = built.index;
    final atStart = order.isEmpty ? null : order[built.windowStart];

    debugPrint('[Sonarar][WINDOW] ${playable.length} of ${built.windowLength} files exist; '
        'want=$path '
        'sample=${atStart == null ? "none" : repo.absoluteFor(atStart) ?? "null"}');

    if (playable.isEmpty) {
      debugPrint('[Sonarar][LOAD] none of the ${built.windowLength} window files exist; '
          'keeping the current queue. first=${atStart?.file ?? "none"}');
      _fileMissing = true;
      return false;
    }

    final bool ok;
    if (idx < 0) {
      debugPrint('[Sonarar][LOAD] not-in-window: window=${built.windowLength} '
          'playable=${playable.length} want=$path '
          'first=${playable.isEmpty ? "none" : playable.first.path}');
      final coverPath = repo.coverPathFor(track);
      ok = await e.loadAndPlay(
        path,
        startAt: effectiveStart,
        autoPlay: autoPlay,
        title: track.title,
        artist: track.artist,
        album: track.album,
        coverUri: (coverPath != null && coverPath.isNotEmpty && _exists(coverPath))
            ? Uri.file(coverPath)
            : null,
      );
    } else {
      final paths = [for (final entry in playable) entry.path];
      if (e.queueMatches(paths)) {
        // The engine already holds exactly this queue. A queue edit that did not
        // change the window lands here — and seeking the track that is already
        // playing back to zero only to seek forward again is an audible rewind.
        // Only move if the engine is somewhere else.
        if (e.playingPath != path) await e.seekToIndex(idx);
        final drift = (e.position - effectiveStart).abs();
        if (effectiveStart > Duration.zero && drift > const Duration(seconds: 1)) {
          await e.seek(effectiveStart);
        }
        if (autoPlay && !e.isPlaying) await e.play();
        ok = true;
      } else if (await e.editQueue(playable, keepPlaying: path)) {
        // The queue moved under a track that did not. Editing the queue in place
        // keeps the platform player running; setQueue would stop it — the music
        // drops for a moment and comes back, which is what a queue edit used to
        // sound like.
        ok = true;
      } else {
        ok = await e.setQueue(playable, initialIndex: idx);

        if (ok && effectiveStart > Duration.zero) await e.seek(effectiveStart);
      }

      if (ok) state.queue?.markEngineSynced();
    }

    _fileMissing = !ok;
    if (ok) _loadedTrackId = track.id;
    return ok;
  }
}
