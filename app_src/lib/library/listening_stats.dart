library;

import 'play_log.dart';

class TrackTally {
  const TrackTally({
    required this.trackId,
    required this.plays,
    required this.completions,
    required this.lastPlayedAt,
  });

  final String trackId;

  final int plays;

  final int completions;

  final DateTime lastPlayedAt;

  double get completionRate => plays == 0 ? 0 : completions / plays;

  bool get isThinSample => plays < 3;
}

class BandTally {
  const BandTally({required this.band, required this.plays});

  final String band;
  final int plays;
}

class ListeningStats {
  const ListeningStats({
    required this.totalPlays,
    required this.totalCompletions,
    required this.mostPlayed,
    required this.byBand,
    required this.firstPlayedAt,
    required this.lastPlayedAt,
    required this.playsByDay,
  });

  final int totalPlays;
  final int totalCompletions;

  final List<TrackTally> mostPlayed;

  final List<BandTally> byBand;

  final DateTime? firstPlayedAt;
  final DateTime? lastPlayedAt;

  final Map<DateTime, int> playsByDay;

  bool get isEmpty => totalPlays == 0;

  TrackTally? get top => mostPlayed.isEmpty ? null : mostPlayed.first;

  bool get isThinSample => totalPlays < 10;
}

ListeningStats summarise(
  List<PlayEvent> events, {
  int limit = 10,
}) {
  final tallies = <String, TrackTally>{};
  final bands = <String, int>{};
  final byDay = <DateTime, int>{};

  var totalPlays = 0;
  var totalCompletions = 0;
  DateTime? first;
  DateTime? last;

  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    final finished = e.completed;

    totalPlays++;
    if (finished) totalCompletions++;

    bands[e.band] = (bands[e.band] ?? 0) + 1;

    final day = DateTime(e.at.year, e.at.month, e.at.day);
    byDay[day] = (byDay[day] ?? 0) + 1;

    final prev = tallies[e.trackId];
    tallies[e.trackId] = TrackTally(
      trackId: e.trackId,
      plays: (prev?.plays ?? 0) + 1,
      completions: (prev?.completions ?? 0) + (finished ? 1 : 0),
      lastPlayedAt: prev == null || e.at.isAfter(prev.lastPlayedAt)
          ? e.at
          : prev.lastPlayedAt,
    );

    if (first == null || e.at.isBefore(first)) first = e.at;
    if (last == null || e.at.isAfter(last)) last = e.at;
  }

  final ordered = tallies.values.toList()
    ..sort((a, b) {
      final byPlays = b.plays.compareTo(a.plays);
      if (byPlays != 0) return byPlays;
      final byDone = b.completions.compareTo(a.completions);
      if (byDone != 0) return byDone;
      return b.lastPlayedAt.compareTo(a.lastPlayedAt);
    });

  final bandList = bands.entries.map((e) => BandTally(band: e.key, plays: e.value)).toList()
    ..sort((a, b) => b.plays.compareTo(a.plays));

  return ListeningStats(
    totalPlays: totalPlays,
    totalCompletions: totalCompletions,
    mostPlayed: ordered.take(limit).toList(growable: false),
    byBand: bandList,
    firstPlayedAt: first,
    lastPlayedAt: last,
    playsByDay: byDay,
  );
}

List<PlayEvent> eventsInYear(List<PlayEvent> events, int year) =>
    events.where((e) => e.at.year == year).toList(growable: false);
