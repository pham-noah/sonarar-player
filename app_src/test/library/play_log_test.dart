library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/listening_stats.dart';
import 'package:sonarar/library/play_log.dart';

PlayEvent _e(
  String id, {
  required DateTime at,
  String band = 'evening',
  int positionMs = 180000,
  int durationMs = 180000,
}) =>
    PlayEvent(
      trackId: id,
      at: at,
      band: band,
      positionMs: positionMs,
      durationMs: durationMs,
    );

void main() {
  group('a play is classified per event, not frozen at write time', () {
    test('played to the end is a completion', () {
      expect(
        _e('t', at: DateTime(2026, 1, 1), positionMs: 179000, durationMs: 180000)
            .completed,
        isTrue,
      );
    });

    test('stopped well before the end is not', () {
      expect(
        _e('t', at: DateTime(2026, 1, 1), positionMs: 60000, durationMs: 180000)
            .completed,
        isFalse,
      );
    });

    test('a zero-length track is not a completion — no divide-by-nothing', () {
      expect(
        _e('t', at: DateTime(2026, 1, 1), durationMs: 0).completed,
        isFalse,
      );
    });
  });

  group('append and read back', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('personar-log'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('events come back in the order they were written', () async {
      final log = PlayLog(File('${dir.path}/plays.jsonl'));
      final at = DateTime(2026, 3, 1, 20);
      for (var i = 0; i < 3; i++) {
        expect(await log.append(_e('t$i', at: at.add(Duration(minutes: i)))), isTrue);
      }
      final back = await log.read();
      expect(back.map((e) => e.trackId).toList(), ['t0', 't1', 't2']);
      expect(await log.count(), 3);
    });

    test('a missing file reads as empty, not as an error', () async {
      final log = PlayLog(File('${dir.path}/nope.jsonl'));
      expect(await log.read(), isEmpty);
      expect(await log.count(), 0);
    });

    test('a TRUNCATED last line is skipped — the reason append-only is safe',
        () async {
      final f = File('${dir.path}/plays.jsonl');
      final log = PlayLog(f);
      await log.append(_e('good', at: DateTime(2026, 2, 2)));
      await f.writeAsString('{"track_id":"half","at":"2026-02-', mode: FileMode.append);

      final back = await log.read();
      expect(back.length, 1);
      expect(back.single.trackId, 'good');
    });

    test('a corrupt line in the MIDDLE does not take the rest with it', () async {
      final f = File('${dir.path}/plays.jsonl');
      f.writeAsStringSync(
        '{"track_id":"a","at":"2026-02-02T10:00:00.000"}\n'
        'not json at all\n'
        '{"track_id":"b","at":"2026-02-02T11:00:00.000"}\n'
        '{"no_track_id":true}\n'
        '{"track_id":"c","at":"2026-02-02T12:00:00.000"}\n',
      );
      final back = await PlayLog(f).read();
      expect(back.map((e) => e.trackId).toList(), ['a', 'b', 'c']);
    });

    test('a huge log is read from the tail, and the fragment is dropped',
        () async {
      final f = File('${dir.path}/plays.jsonl');
      final log = PlayLog(f, maxReadBytes: 300);
      final at = DateTime(2026, 2, 2);
      for (var i = 0; i < 40; i++) {
        await log.append(_e('t$i', at: at.add(Duration(minutes: i))));
      }
      final back = await log.read();
      expect(back, isNotEmpty);

      for (final e in back) {
        expect(e.trackId, startsWith('t'));
        expect(e.at.year, 2026);
      }

      expect(back.last.trackId, 't39');
    });
  });

  group('stats count plays, not starts', () {
    final day = DateTime(2026, 5, 1, 20);

    test('a track skipped in the first ten seconds is not a play', () {
      final s = summarise([
        _e('skipme', at: day, positionMs: 4000, durationMs: 180000),
      ]);
      expect(s.totalPlays, 0);
      expect(s.isEmpty, isTrue);
      expect(s.mostPlayed, isEmpty);
    });

    test('a completion counts as both a play and a completion', () {
      final s = summarise([
        _e('t', at: day, positionMs: 179500, durationMs: 180000),
      ]);
      expect(s.totalPlays, 1);
      expect(s.totalCompletions, 1);
    });

    test('a track played past the threshold but not finished counts as a play',
        () {
      final s = summarise([
        _e('t', at: day, positionMs: 60000, durationMs: 300000),
      ]);
      expect(s.totalPlays, 1);
      expect(s.totalCompletions, 0);
    });

    test('most-played is ordered by plays, then completions, then recency', () {
      final s = summarise([
        _e('twice', at: day),
        _e('twice', at: day.add(const Duration(hours: 1))),
        _e('once', at: day),
      ]);
      expect(s.mostPlayed.first.trackId, 'twice');
      expect(s.mostPlayed.first.plays, 2);
      expect(s.top!.trackId, 'twice');
    });

    test('a tie on plays is broken by completions, not by insertion order', () {
      final s = summarise([

        _e('partial', at: day, positionMs: 60000, durationMs: 300000),
        _e('partial', at: day.add(const Duration(hours: 5)),
            positionMs: 60000, durationMs: 300000),
        _e('heard-through', at: day, positionMs: 179500, durationMs: 180000),
        _e('heard-through', at: day.add(const Duration(hours: 6)),
            positionMs: 179500, durationMs: 180000),
      ]);
      expect(s.mostPlayed.first.trackId, 'heard-through');
      expect(s.mostPlayed.first.completions, 2);
    });

    test('the limit caps the list', () {
      final s = summarise(
        [for (var i = 0; i < 20; i++) _e('t$i', at: day)],
        limit: 5,
      );
      expect(s.mostPlayed.length, 5);
      expect(s.totalPlays, 20, reason: 'the total must still be the real total');
    });

    test('plays are grouped by band, most first', () {
      final s = summarise([
        _e('a', at: day, band: 'evening'),
        _e('b', at: day, band: 'evening'),
        _e('c', at: day, band: 'morning'),
      ]);
      expect(s.byBand.first.band, 'evening');
      expect(s.byBand.first.plays, 2);
      expect(s.byBand.last.band, 'morning');
    });

    test('plays are grouped by local calendar day', () {
      final s = summarise([
        _e('a', at: DateTime(2026, 5, 1, 23, 59)),
        _e('b', at: DateTime(2026, 5, 2, 0, 1)),
        _e('c', at: DateTime(2026, 5, 2, 12)),
      ]);
      expect(s.playsByDay[DateTime(2026, 5, 1)], 1);
      expect(s.playsByDay[DateTime(2026, 5, 2)], 2);
    });

    test('the first and last play are reported', () {
      final s = summarise([
        _e('a', at: DateTime(2026, 1, 1)),
        _e('b', at: DateTime(2026, 6, 1)),
      ]);
      expect(s.firstPlayedAt, DateTime(2026, 1, 1));
      expect(s.lastPlayedAt, DateTime(2026, 6, 1));
    });

    test('a small history says so rather than drawing a confident chart', () {
      final s = summarise([_e('a', at: day), _e('b', at: day)]);
      expect(s.isThinSample, isTrue);
      final big = summarise([for (var i = 0; i < 12; i++) _e('t$i', at: day)]);
      expect(big.isThinSample, isFalse);
    });

    test('a completion rate is not claimed from a single play', () {
      final s = summarise([_e('a', at: day, positionMs: 179500, durationMs: 180000)]);
      final t = s.mostPlayed.single;
      expect(t.completionRate, 1.0);
      expect(t.isThinSample, isTrue, reason: 'one play cannot establish a rate');
    });

    test('an empty log produces empty stats, not a crash', () {
      final s = summarise(const []);
      expect(s.isEmpty, isTrue);
      expect(s.totalPlays, 0);
      expect(s.top, isNull);
      expect(s.firstPlayedAt, isNull);
      expect(s.playsByDay, isEmpty);
    });
  });

  group('yearly recap', () {
    test('only the requested year is included', () {
      final events = [
        _e('old', at: DateTime(2025, 12, 31)),
        _e('this', at: DateTime(2026, 1, 1)),
        _e('next', at: DateTime(2027, 1, 1)),
      ];
      final y26 = eventsInYear(events, 2026);
      expect(y26.length, 1);
      expect(y26.single.trackId, 'this');
    });
  });
}
