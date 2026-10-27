library;

import 'play_log.dart';

class DayShape {
  const DayShape({
    required this.date,
    required this.plays,
    required this.completions,
    this.listenedMs = 0,
    required this.mostPlayedTrackId,
    required this.mostPlayedCount,
    required this.byBand,
    required this.playedInTheRain,
    required this.playedDry,
    required this.knownWeather,
  });

  final DateTime date;
  final int plays;
  final int completions;

  final int listenedMs;

  final String? mostPlayedTrackId;
  final int mostPlayedCount;

  final Map<String, int> byBand;

  final int playedInTheRain;
  final int playedDry;
  final int knownWeather;

  bool get isEmpty => plays == 0;

  double intensity(int monthPeak) {
    if (plays == 0) return 0;
    if (monthPeak <= 0) return 0;
    final v = plays / monthPeak;

    return v < 0.25 ? 0.25 : v;
  }
}

class MonthShape {
  const MonthShape({
    required this.year,
    required this.month,
    required this.days,
    required this.totalPlays,
    required this.peakPlays,
  });

  final int year;
  final int month;

  final List<DayShape> days;

  final int totalPlays;

  final int peakPlays;

  bool get isEmpty => totalPlays == 0;
  int get daysWithPlays => days.where((d) => !d.isEmpty).length;
}

DateTime previousMonth(DateTime m) =>
    m.month == 1 ? DateTime(m.year - 1, 12) : DateTime(m.year, m.month - 1);

DateTime nextMonth(DateTime m) =>
    m.month == 12 ? DateTime(m.year + 1, 1) : DateTime(m.year, m.month + 1);

class HistoryShape {
  const HistoryShape({
    required this.month,
    required this.recentDays,
    required this.byBand,
    required this.totalPlays,
    required this.totalCompletions,
    required this.rain,
    required this.thinSample,
    this.playsByTrack = const {},
    this.msByTrack = const {},
    this.msByBand = const {},
    this.listenedMs = 0,
    this.discovery,
  });

  final MonthShape month;

  final List<DayShape> recentDays;

  final List<(String, int)> byBand;

  final int totalPlays;
  final int totalCompletions;

  final RainSplit? rain;

  final Map<String, int> playsByTrack;
  final Map<String, int> msByTrack;

  final Map<String, int> msByBand;

  final int listenedMs;

  final DiscoverySplit? discovery;

  final bool thinSample;
}

class RainSplit {
  const RainSplit({
    required this.rainPlays,
    required this.dryPlays,
    required this.rainCompletions,
    required this.dryCompletions,
  });

  final int rainPlays;
  final int dryPlays;
  final int rainCompletions;
  final int dryCompletions;

  int get known => rainPlays + dryPlays;

  double? get rainFinishRate =>
      rainPlays < 3 ? null : rainCompletions / rainPlays;
  double? get dryFinishRate =>
      dryPlays < 3 ? null : dryCompletions / dryPlays;
}

const List<String> kBandOrder = [
  'morning',
  'afternoon',
  'evening',
  'night',
  'darkHour',
];

DayShape dayShapeFor(List<PlayEvent> events, DateTime date) {
  final counts = <String, int>{};
  final bands = <String, int>{};
  var plays = 0;
  var completions = 0;
  var rain = 0;
  var dry = 0;
  var listened = 0;

  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    if (e.at.year != date.year ||
        e.at.month != date.month ||
        e.at.day != date.day) {
      continue;
    }
    plays++;
    if (e.completed) completions++;
    listened += e.positionMs;
    counts[e.trackId] = (counts[e.trackId] ?? 0) + 1;
    bands[e.band] = (bands[e.band] ?? 0) + 1;

    if (e.raining == true) {
      rain++;
    } else if (e.raining == false) {
      dry++;
    }
  }

  String? topId;
  var topCount = 0;
  final ids = counts.keys.toList()..sort();
  for (final id in ids) {
    if (counts[id]! > topCount) {
      topCount = counts[id]!;
      topId = id;
    }
  }

  return DayShape(
    date: DateTime(date.year, date.month, date.day),
    plays: plays,
    completions: completions,
    listenedMs: listened,
    mostPlayedTrackId: topId,
    mostPlayedCount: topCount,
    byBand: bands,
    playedInTheRain: rain,
    playedDry: dry,
    knownWeather: rain + dry,
  );
}

MonthShape monthShapeFor(List<PlayEvent> events, int year, int month) {
  final daysInMonth = DateTime(year, month + 1, 0).day;

  final days = <DayShape>[];
  for (var d = 1; d <= daysInMonth; d++) {
    days.add(dayShapeFor(events, DateTime(year, month, d)));
  }

  var peak = 0;
  for (final d in days) {
    if (d.plays > peak) peak = d.plays;
  }

  return MonthShape(
    year: year,
    month: month,
    days: days,
    totalPlays: days.fold(0, (sum, d) => sum + d.plays),
    peakPlays: peak,
  );
}

List<DateTime> monthsWithPlays(List<PlayEvent> events) {
  final seen = <DateTime>{};
  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    seen.add(DateTime(e.at.year, e.at.month));
  }
  final out = seen.toList()..sort((a, b) => b.compareTo(a));
  return out;
}

HistoryShape buildHistory(
  List<PlayEvent> events, {
  required int year,
  required int month,
  int recentCount = 14,
  DateTime? now,
}) {
  final monthShape = monthShapeFor(events, year, month);

  final byDay = <DateTime, List<PlayEvent>>{};
  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    final d = DateTime(e.at.year, e.at.month, e.at.day);
    (byDay[d] ??= []).add(e);
  }
  final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  final recent = [
    for (final d in dayKeys.take(recentCount)) dayShapeFor(events, d),
  ];

  final bandTotals = <String, int>{};
  var plays = 0;
  var completions = 0;
  var rainPlays = 0;
  var dryPlays = 0;
  var rainDone = 0;
  var listened = 0;
  final playsByTrack = <String, int>{};
  final msByTrack = <String, int>{};
  final msByBand = <String, int>{};
  var dryDone = 0;

  for (final e in events) {
    if (!isCountedPlay(e)) continue;
    plays++;
    if (e.completed) completions++;
    bandTotals[e.band] = (bandTotals[e.band] ?? 0) + 1;
    msByBand[e.band] = (msByBand[e.band] ?? 0) + e.positionMs;
    playsByTrack[e.trackId] = (playsByTrack[e.trackId] ?? 0) + 1;
    msByTrack[e.trackId] = (msByTrack[e.trackId] ?? 0) + e.positionMs;
    listened += e.positionMs;

    if (e.raining == true) {
      rainPlays++;
      if (e.completed) rainDone++;
    } else if (e.raining == false) {
      dryPlays++;
      if (e.completed) dryDone++;
    }
  }

  return HistoryShape(
    month: monthShape,
    recentDays: recent,
    byBand: [
      for (final b in kBandOrder)
        if ((bandTotals[b] ?? 0) > 0) (b, bandTotals[b]!),

      for (final e in bandTotals.entries)
        if (!kBandOrder.contains(e.key)) (e.key, e.value),
    ],
    totalPlays: plays,
    totalCompletions: completions,

    rain: (rainPlays + dryPlays) == 0
        ? null
        : RainSplit(
            rainPlays: rainPlays,
            dryPlays: dryPlays,
            rainCompletions: rainDone,
            dryCompletions: dryDone,
          ),
    thinSample: plays < 10,
    playsByTrack: playsByTrack,
    msByTrack: msByTrack,
    msByBand: msByBand,
    listenedMs: listened,
    discovery: discoverySplit(events, now: now),
  );
}

class DiscoverySplit {
  const DiscoverySplit({required this.newTracks, required this.repeatTracks});

  final int newTracks;

  final int repeatTracks;

  int get total => newTracks + repeatTracks;

  double? get newShare => total == 0 ? null : newTracks / total;
}

const int kDiscoveryWindowDays = 30;

const int kDiscoveryMinTracks = 5;

DiscoverySplit? discoverySplit(List<PlayEvent> events, {DateTime? now}) {
  final counted = [for (final e in events) if (isCountedPlay(e)) e];
  if (counted.isEmpty) return null;

  final ref = now ?? counted.last.at;
  final from = ref.subtract(const Duration(days: kDiscoveryWindowDays));

  final firstPlay = <String, DateTime>{};
  for (final e in counted) {
    final seen = firstPlay[e.trackId];
    if (seen == null || e.at.isBefore(seen)) firstPlay[e.trackId] = e.at;
  }

  var fresh = 0;
  var repeat = 0;
  for (final id in firstPlay.keys) {
    final first = firstPlay[id]!;

    final playedInWindow = counted.any((e) => e.trackId == id && !e.at.isBefore(from));
    if (!playedInWindow) continue;
    if (!first.isBefore(from)) {
      fresh++;
    } else {
      repeat++;
    }
  }

  if (fresh + repeat < kDiscoveryMinTracks) return null;
  return DiscoverySplit(newTracks: fresh, repeatTracks: repeat);
}
