/// The stretch of the queue the engine is handed when the current track changes.
///
/// The engine is never given the whole queue. A window of [engineWindowChunk]
/// tracks around the one being played is cheap to set up, keeps a large library
/// from being stat-ed on every track change, and is what the player already
/// behaves like: next and previous move inside the window, and the shell reloads
/// when they reach its edge.
///
/// Only files that exist reach the engine. A missing file inside the window must
/// not stop the track that does exist, so the entries are filtered first and the
/// index is reported against what survived.
library;

import '../library/track.dart';

/// One engine queue entry: what the lock screen is given to name a file.
typedef EngineEntry = ({
  String path,
  String title,
  String artist,
  String album,
  Uri? cover,
});

/// How many tracks the engine is handed at a time.
const int engineWindowChunk = 24;

/// A resolved window: the entries the engine can play, where the wanted track
/// sits among them, and how much of the queue the window covered.
class EngineWindow {
  const EngineWindow({
    required this.entries,
    required this.index,
    required this.windowStart,
    required this.windowLength,
  });

  final List<EngineEntry> entries;

  /// Where the wanted track sits in [entries], or -1 when its file is not there.
  final int index;

  /// Index into the queue of the window's first track.
  final int windowStart;

  /// How many queue tracks the window covered, playable or not.
  final int windowLength;

  bool get isEmpty => entries.isEmpty;

  bool get hasTarget => index >= 0;
}

/// Builds the window around [track].
///
/// [pathFor] / [coverFor] resolve a track against the library root, and [exists]
/// answers whether a file is really on the disk — both injected so this stays a
/// pure function with no filesystem of its own.
EngineWindow engineWindowFor({
  required List<Track> order,
  required Track track,
  required String? Function(Track) pathFor,
  required String? Function(Track) coverFor,
  required bool Function(String path) exists,
  int chunk = engineWindowChunk,
}) {
  if (chunk <= 0) throw ArgumentError.value(chunk, 'chunk', 'must be positive');

  final at = order.indexWhere((t) => t.id == track.id);
  final start = at < 0 ? 0 : (at ~/ chunk) * chunk;
  final end = (start + chunk).clamp(0, order.length);
  final window = start < end ? order.sublist(start, end) : const <Track>[];

  final wantedPath = pathFor(track);
  final entries = <EngineEntry>[];
  for (final t in window) {
    final path = pathFor(t);
    if (path == null || path.isEmpty || !exists(path)) continue;
    final cover = coverFor(t);
    entries.add((
      path: path,
      title: t.title,
      artist: t.artist,
      album: t.album,
      cover: (cover != null && cover.isNotEmpty && exists(cover))
          ? Uri.file(cover)
          : null,
    ));
  }

  return EngineWindow(
    entries: List.unmodifiable(entries),
    index: wantedPath == null ? -1 : entries.indexWhere((e) => e.path == wantedPath),
    windowStart: start,
    windowLength: window.length,
  );
}
