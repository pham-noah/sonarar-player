library;

import 'search_fold.dart';
import 'compendium.dart';
import 'play_log.dart';
import 'playlists.dart';
import 'track.dart';

const int kRecapDays = 30;

const int kRailLength = 12;

const int kNewFromLibraryFloor = 12;

typedef HomeRails = ({
  Track? continueListening,

  List<Track> jumpBackIn,

  List<Track> heavyRotation,

  List<Track> recap,

  List<Track> newFromLibrary,
});

typedef PlaylistPlays = ({Playlist playlist, int plays});

/// How many counted plays each track has, over the whole log.
///
/// Separate from the ranking because the log grows with every listen and the
/// ranking runs on every rebuild: a caller that rebuilds often can hold this
/// map for as long as the log is unchanged and redo only the cheap part.
Map<String, int> countPlaysByTrack(List<PlayEvent> events) {
  final playsByTrack = <String, int>{};
  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    playsByTrack[e.trackId] = (playsByTrack[e.trackId] ?? 0) + 1;
  }
  return playsByTrack;
}

List<PlaylistPlays> rankPlaylistsByPlays({
  required List<Playlist> playlists,
  required List<PlayEvent> events,
  Map<String, int>? counts,
}) {
  final playsByTrack = counts ?? countPlaysByTrack(events);

  final ranked = <PlaylistPlays>[
    for (final p in playlists)
      (
        playlist: p,
        plays: p.trackIds.fold<int>(0, (sum, id) => sum + (playsByTrack[id] ?? 0)),
      ),
  ];

  ranked.sort((a, b) {
    final byPlays = b.plays.compareTo(a.plays);
    if (byPlays != 0) return byPlays;
    return compareFolded(a.playlist.name, b.playlist.name);
  });
  return ranked;
}

HomeRails deriveHomeRails({
  required List<Track> tracks,
  required List<PlayEvent> events,
  required DateTime now,
}) {
  final byId = {for (final t in tracks) t.id: t};

  final seen = <String>{};
  final recent = <Track>[];
  for (final e in events.reversed) {
    if (!seen.add(e.trackId)) continue;
    final t = byId[e.trackId];
    if (t == null) continue;
    recent.add(t);
    if (recent.length >= kRailLength) break;
  }

  final compendium = buildCompendium(tracks: tracks, events: events);
  final rotation =
      (compendium.entries.where((e) => e.plays >= 2).toList()
            ..sort((a, b) => b.plays.compareTo(a.plays)))
          .take(kRailLength)

          .map((e) => e.track)
          .toList();

  final cutoff = now.subtract(const Duration(days: kRecapDays));
  final recapSeen = <String>{};
  final recap = <Track>[];
  for (final e in events.reversed) {
    if (e.at.isBefore(cutoff)) continue;
    if (!recapSeen.add(e.trackId)) continue;
    final t = byId[e.trackId];
    if (t == null) continue;
    recap.add(t);
    if (recap.length >= kRailLength) break;
  }

  final newFromLibrary = tracks.length <= kNewFromLibraryFloor
      ? const <Track>[]
      : tracks.sublist(tracks.length - kRailLength).reversed.toList();

  return (
    continueListening: recent.isEmpty ? null : recent.first,
    jumpBackIn: recent.skip(1).toList(growable: false),
    heavyRotation: rotation,
    recap: recap,
    newFromLibrary: newFromLibrary,
  );
}
