library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/compendium.dart';
import 'package:sonarar/library/history.dart';
import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/track.dart';

PlayEvent _e(
  String id, {
  required DateTime at,
  String band = 'evening',
  int positionMs = 180000,
  int durationMs = 180000,
  bool? raining,
  String? mode,
}) =>
    PlayEvent(
      trackId: id,
      at: at,
      band: band,
      positionMs: positionMs,
      durationMs: durationMs,
      raining: raining,
      mode: mode,
    );

void main() {
  final day = DateTime(2026, 10, 14, 20);

  group('a day', () {
    test('counts only what counts, and reports the most played', () {
      final d = dayShapeFor([
        _e('a', at: day),
        _e('a', at: day.add(const Duration(hours: 1))),
        _e('b', at: day.add(const Duration(hours: 2))),
      ], day);
      expect(d.plays, 3);
      expect(d.mostPlayedTrackId, 'a');
      expect(d.mostPlayedCount, 2);
    });

    test('a short skip does not appear in the day at all', () {
      final d = dayShapeFor([
        _e('a', at: day, positionMs: 3000),
      ], day);
      expect(d.plays, 0);
      expect(d.isEmpty, isTrue);
    });

    test('events from another day are not counted', () {
      final d = dayShapeFor([
        _e('a', at: day.add(const Duration(days: 1))),
      ], day);
      expect(d.isEmpty, isTrue);
    });

    test('a tie picks the same track every time', () {
      final first = dayShapeFor([
        _e('z', at: day),
        _e('a', at: day.add(const Duration(minutes: 5))),
      ], day);
      final second = dayShapeFor([
        _e('a', at: day),
        _e('z', at: day.add(const Duration(minutes: 5))),
      ], day);
      expect(first.mostPlayedTrackId, second.mostPlayedTrackId);
    });

    test('completions are counted separately from plays', () {
      final d = dayShapeFor([
        _e('a', at: day),
        _e('b', at: day, positionMs: 5000),
      ], day);
      expect(d.plays, 1, reason: 'the short one is not a play');
      expect(d.completions, 1);
    });

    test('the band split is per band, for the day bar', () {
      final d = dayShapeFor([
        _e('a', at: day, band: 'morning'),
        _e('b', at: day, band: 'morning'),
        _e('c', at: day, band: 'night'),
      ], day);
      expect(d.byBand['morning'], 2);
      expect(d.byBand['night'], 1);
      expect(d.byBand['evening'], isNull);
    });
  });

  group('a month', () {
    test('every day is present, including empty ones', () {
      final m = monthShapeFor([], 2026, 10);
      expect(m.days.length, 31);
      expect(m.days.every((d) => d.isEmpty), isTrue);
    });

    test('February in a leap year has 29 days', () {
      expect(monthShapeFor([], 2028, 2).days.length, 29);
    });

    test('February in a normal year has 28', () {
      expect(monthShapeFor([], 2026, 2).days.length, 28);
    });

    test('a 30-day month has 30', () {
      expect(monthShapeFor([], 2026, 4).days.length, 30);
    });

    test('December does not run off the end of the year', () {
      expect(monthShapeFor([], 2026, 12).days.length, 31);
    });

    test('an empty month reports itself empty rather than looking broken', () {
      final m = monthShapeFor([], 2026, 10);
      expect(m.isEmpty, isTrue);
      expect(m.daysWithPlays, 0);
    });

    test('the peak drives cell intensity, so a quiet month still has shape',
        () {
      final m = monthShapeFor([
        _e('a', at: day),
        _e('b', at: day.add(const Duration(hours: 1))),
        _e('c', at: day.add(const Duration(days: 1))),
      ], 2026, 10);
      expect(m.peakPlays, 2);

      final busy = m.days.firstWhere((d) => d.plays == 2);
      final quiet = m.days.firstWhere((d) => d.plays == 1);
      expect(busy.intensity(m.peakPlays), 1.0);

      expect(quiet.intensity(m.peakPlays), greaterThanOrEqualTo(0.25));
      expect(quiet.intensity(m.peakPlays), lessThan(1.0));
    });

    test('an empty day has zero intensity and cannot divide by zero', () {
      final m = monthShapeFor([], 2026, 10);
      expect(m.days.first.intensity(0), 0);
      expect(m.days.first.intensity(m.peakPlays), 0);
    });
  });

  group('month navigation', () {
    test('back from January is December of the year before', () {
      expect(previousMonth(DateTime(2026, 1)), DateTime(2025, 12));
    });

    test('forward from December is January of the year after', () {
      expect(nextMonth(DateTime(2026, 12)), DateTime(2027, 1));
    });

    test('the ordinary cases move by one', () {
      expect(previousMonth(DateTime(2026, 6)), DateTime(2026, 5));
      expect(nextMonth(DateTime(2026, 6)), DateTime(2026, 7));
    });

    test('only months that have one are listed, newest first', () {
      final events = [
        _e('a', at: DateTime(2026, 3, 4)),
        _e('b', at: DateTime(2026, 10, 1)),
      ];
      final months = monthsWithPlays(events);
      expect(months.first, DateTime(2026, 10));
      expect(months.length, 2);
    });

    test('a month where everything was skipped is not offered', () {
      final months = monthsWithPlays([
        _e('a', at: DateTime(2026, 5, 2), positionMs: 2000),
      ]);
      expect(months, isEmpty);
    });
  });

  group('the shared definition of a play', () {
    test('a 10-second boundary is treated identically everywhere', () {
      expect(isCountedPlay(_e('a', at: day, positionMs: 10000)), isTrue);
      expect(isCountedPlay(_e('a', at: day, positionMs: 9999)), isFalse);
    });

    test('a short track heard through counts, even under the threshold', () {
      final short = _e('a', at: day, positionMs: 8000, durationMs: 8000);
      expect(isCountedPlay(short), isTrue,
          reason: 'a completed play counts however short it was');
    });
  });

  group('the weather split — the reason raining was added to the log', () {
    test('a play with no weather is counted in NEITHER bucket', () {
      final h = buildHistory([
        _e('a', at: day),
      ], year: 2026, month: 10);
      expect(h.rain, isNull,
          reason: 'no known weather means no chart, not an empty one');
    });

    test('the split appears once any play carries a reading', () {
      final h = buildHistory([
        _e('a', at: day, raining: true),
        _e('b', at: day, raining: false),
        _e('c', at: day),
      ], year: 2026, month: 10);
      expect(h.rain, isNotNull);
      expect(h.rain!.rainPlays, 1);
      expect(h.rain!.dryPlays, 1);
      expect(h.rain!.known, 2, reason: 'the unknown play is in neither');
    });

    test('a finish rate is withheld below three samples', () {
      final two = buildHistory([
        _e('a', at: day, raining: true),
        _e('b', at: day, raining: true),
      ], year: 2026, month: 10);
      expect(two.rain!.rainFinishRate, isNull,
          reason: 'a rate from two plays is not a rate');

      final three = buildHistory([
        _e('a', at: day, raining: true),
        _e('b', at: day, raining: true),
        _e('c', at: day, raining: true),
      ], year: 2026, month: 10);
      expect(three.rain!.rainFinishRate, 1.0);
    });

    test('the day detail knows rain from dry, and ignores unknown', () {
      final d = dayShapeFor([
        _e('a', at: day, raining: true),
        _e('b', at: day, raining: true),
        _e('c', at: day, raining: false),
        _e('d', at: day),
      ], day);
      expect(d.playedInTheRain, 2);
      expect(d.playedDry, 1);
      expect(d.knownWeather, 3);
      expect(d.plays, 4, reason: 'the unknown one is still a play');
    });
  });

  group('the shape of the whole history', () {
    test('the band chart is ordered by the DAY, not by count', () {
      final h = buildHistory([
        _e('a', at: day, band: 'night'),
        _e('b', at: day, band: 'night'),
        _e('c', at: day, band: 'night'),
        _e('d', at: day, band: 'morning'),
      ], year: 2026, month: 10);
      expect(h.byBand.first.$1, 'morning');
      expect(h.byBand.last.$1, 'night');
    });

    test('recent days are the last N days WITH plays, newest first', () {
      final h = buildHistory([
        _e('a', at: day),
        _e('b', at: day.subtract(const Duration(days: 3))),
      ], year: 2026, month: 10, recentCount: 5);
      expect(h.recentDays.length, 2);
      expect(h.recentDays.first.date.day, day.day);
    });

    test('fewer than ten plays is reported as a thin sample', () {
      final h = buildHistory([
        _e('a', at: day),
      ], year: 2026, month: 10);
      expect(h.thinSample, isTrue);

      final many = buildHistory([
        for (var i = 0; i < 10; i++)
          _e('t$i', at: day.add(Duration(minutes: i))),
      ], year: 2026, month: 10);
      expect(many.thinSample, isFalse);
    });
  });

  group('the compendium — every track, played or not', () {
    test('an unheard track is INCLUDED, which is the point', () {
      final c = buildCompendium(
        tracks: _tracks(3),
        events: [_e('t0', at: day)],
      );
      expect(c.length, 3);
      expect(c.heardCount, 1);
      expect(c.entries.where((e) => e.neverHeard).length, 2);
      expect(c.heardShare, closeTo(1 / 3, 0.001));
    });

    test('a never-heard entry has no date, not an epoch date', () {
      final c = buildCompendium(tracks: _tracks(1), events: const []);
      expect(c.entries.first.lastPlayedAt, isNull,
          reason: 'an epoch date would display as "56 years ago"');
    });

    test('a rate is withheld below three plays here too', () {
      final c = buildCompendium(
        tracks: _tracks(1),
        events: [_e('t0', at: day), _e('t0', at: day.add(const Duration(hours: 1)))],
      );
      expect(c.entries.first.plays, 2);
      expect(c.entries.first.completionRate, isNull);
    });

    test('an empty library does not divide by zero', () {
      final c = buildCompendium(tracks: const [], events: const []);
      expect(c.isEmpty, isTrue);
      expect(c.heardShare, 0);
    });

    test('a log line for a track no longer in the library does not inflate it',
        () {
      final c = buildCompendium(
        tracks: _tracks(1),
        events: [_e('t0', at: day), _e('gone', at: day)],
      );
      expect(c.heardCount, 1,
          reason: 'heard is counted from the library, not from the log');
    });
  });
}

List<Track> _tracks(int n) => [
      for (var i = 0; i < n; i++)
        Track(
          id: 't$i',
          title: 'Track $i',
          artist: 'ATLUS Sound Team',
          album: 'Persona 3 Reload',
          duration: const Duration(seconds: 180),
          file: 't$i.m4a',
          cover: '',
          gainDb: 0,
        ),
    ];
