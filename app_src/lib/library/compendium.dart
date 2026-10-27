library;

import 'play_log.dart';
import 'track.dart';

class CompendiumEntry {
  const CompendiumEntry({
    required this.track,
    required this.plays,
    required this.completions,
    required this.lastPlayedAt,
  });

  final Track track;

  final int plays;

  final int completions;

  final DateTime? lastPlayedAt;

  bool get neverHeard => plays == 0;

  double? get completionRate =>
      plays < 3 ? null : completions / plays;
}

class Compendium {
  const Compendium({
    required this.entries,
    required this.heardCount,
    required this.totalPlays,
  });

  final List<CompendiumEntry> entries;

  final int heardCount;

  final int totalPlays;

  int get length => entries.length;

  double get heardShare => entries.isEmpty ? 0 : heardCount / entries.length;

  bool get isEmpty => entries.isEmpty;
}

Compendium buildCompendium({
  required List<Track> tracks,
  required List<PlayEvent> events,
}) {
  final plays = <String, int>{};
  final completions = <String, int>{};
  final last = <String, DateTime>{};

  var total = 0;

  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    total++;
    plays[e.trackId] = (plays[e.trackId] ?? 0) + 1;
    if (e.completed) {
      completions[e.trackId] = (completions[e.trackId] ?? 0) + 1;
    }
    final prev = last[e.trackId];
    if (prev == null || e.at.isAfter(prev)) last[e.trackId] = e.at;
  }

  final entries = [
    for (final t in tracks)
      CompendiumEntry(
        track: t,
        plays: plays[t.id] ?? 0,
        completions: completions[t.id] ?? 0,
        lastPlayedAt: last[t.id],
      ),
  ];

  return Compendium(
    entries: entries,

    heardCount: entries.where((e) => !e.neverHeard).length,
    totalPlays: total,
  );
}
