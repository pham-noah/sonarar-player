library;

import 'downloaded_tracks.dart';
import 'dynamic_playlist.dart';
import 'play_log.dart';
import 'playlists.dart';
import 'track.dart';

const String kRediscoverId = '__rediscover__';
const String kForgottenId = '__forgotten__';

const Duration kRediscoverAfter = Duration(days: 90);

class RediscoveryList {
  const RediscoveryList({
    required this.playlist,
    required this.blurb,
    required this.usable,
  });

  final Playlist playlist;

  final String blurb;

  final bool usable;

  bool get isEmpty => playlist.isEmpty;
}

Map<String, DateTime> lastPlayedByTrack(List<PlayEvent> events) {
  final out = <String, DateTime>{};
  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    final prev = out[e.trackId];
    if (prev == null || e.at.isAfter(prev)) out[e.trackId] = e.at;
  }
  return out;
}

List<RediscoveryList> buildRediscovery({
  required List<Track> library,
  required List<PlayEvent> events,
  Set<String> favorites = const {},
  DateTime? now,
  Duration staleAfter = kRediscoverAfter,
  String Function(Track)? titleFor,
}) {
  final at = now ?? DateTime.now();
  final last = lastPlayedByTrack(events);
  final cutoff = at.subtract(staleAfter);
  final anyHistory = last.isNotEmpty;

  bool stale(Track t) {
    final when = last[t.id];
    if (when == null) return anyHistory;
    return when.isBefore(cutoff);
  }

  final staleTracks = [for (final t in library) if (stale(t)) t];

  final rediscoverUsable =
      anyHistory && staleTracks.isNotEmpty && staleTracks.length < library.length;

  final rediscover = RediscoveryList(
    playlist: Playlist(
      id: kRediscoverId,
      name: 'Rediscover',
      trackIds: [for (final t in staleTracks) t.id],
    ),
    blurb: anyHistory
        ? 'Not played in ${staleAfter.inDays} days, or ever. '
            '${staleTracks.length} of ${library.length} tracks.'
        : 'Nothing has been played yet, so there is nothing to rediscover.',
    usable: rediscoverUsable,
  );

  final forgottenTracks = [
    for (final t in library)
      if (favorites.contains(t.id) && stale(t)) t,
  ];

  final forgotten = RediscoveryList(
    playlist: Playlist(
      id: kForgottenId,
      name: 'Loved, then forgotten',
      trackIds: [for (final t in forgottenTracks) t.id],
    ),
    blurb: forgottenTracks.isEmpty
        ? 'Nothing liked has gone quiet.'
        : 'Liked, and not played in ${staleAfter.inDays} days '
            'or more. ${forgottenTracks.length} track'
            '${forgottenTracks.length == 1 ? '' : 's'}.',
    usable: forgottenTracks.isNotEmpty,
  );

  return [rediscover, forgotten];
}

bool isDerivedPlaylistId(String id) =>
    id == kRediscoverId ||
    id == kForgottenId ||
    id == kDownloadedId ||
    id == kDynamicId;

bool isSeededPlaylistId(String id) => !id.startsWith('pl_');
