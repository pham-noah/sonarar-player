library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/history.dart';
import 'package:sonarar/library/play_log.dart';

PlayEvent _e(
  String id, {
  required DateTime at,
  required String band,
  int positionMs = 200000,
  int durationMs = 200000,
}) =>
    PlayEvent(
      trackId: id,
      at: at,
      band: band,
      positionMs: positionMs,
      durationMs: durationMs,
    );

DateTime _day(int d, {int hour = 20}) => DateTime(2026, 10, d, hour);

void main() {
  group('time listened', () {
    test('sums the recorded positions, so a skip counts only as far as it got', () {
      final events = [
        _e('a', at: _day(1), band: 'evening', positionMs: 40000),
        _e('b', at: _day(1), band: 'evening', positionMs: 200000),
      ];
      final h = buildHistory(events, year: 2026, month: 10);
      expect(h.listenedMs, 240000);
    });

    test('counts only what the log would call a play', () {
      final events = [
        _e('a', at: _day(1), band: 'evening', positionMs: 200000),
        _e('b', at: _day(1), band: 'evening', positionMs: 3000),
      ];
      final h = buildHistory(events, year: 2026, month: 10);
      expect(h.listenedMs, 200000, reason: 'the 3s skip is below the counted-play floor');
    });

    test('is zero, not a crash, when nothing was played', () {
      final h = buildHistory(const [], year: 2026, month: 10);
      expect(h.listenedMs, 0);
      expect(h.playsByTrack, isEmpty);
    });
  });

  group('top tracks', () {
    test('per-track time accumulates, so one long listen beats many short ones', () {
      final events = [

        _e('short', at: _day(1, hour: 9), band: 'morning', positionMs: 10000),
        _e('short', at: _day(1, hour: 10), band: 'morning', positionMs: 10000),
        _e('short', at: _day(1, hour: 11), band: 'morning', positionMs: 10000),

        _e('long', at: _day(1, hour: 20), band: 'evening', positionMs: 360000, durationMs: 363000),
      ];
      final h = buildHistory(events, year: 2026, month: 10);

      expect(h.playsByTrack['short'], 3);
      expect(h.playsByTrack['long'], 1);

      expect(h.msByTrack['short'], 30000);
      expect(h.msByTrack['long'], 360000);
    });
  });

  group('discovery', () {
    test('a track heard first inside the window is NEW', () {
      final now = _day(30);
      final events = [
        _e('a', at: _day(2), band: 'evening'),
        _e('b', at: _day(3), band: 'evening'),
        _e('c', at: _day(4), band: 'evening'),
        _e('d', at: _day(5), band: 'evening'),
        _e('e', at: _day(6), band: 'evening'),
      ];
      final d = discoverySplit(events, now: now);
      expect(d, isNotNull);
      expect(d!.newTracks, 5);
      expect(d.repeatTracks, 0);
      expect(d.newShare, 1.0);
    });

    test('a track FIRST heard long ago is KNOWN, however often it is played now', () {
      final now = _day(30);
      final events = [

        _e('old', at: DateTime(2026, 6, 1), band: 'evening'),

        _e('old', at: _day(10), band: 'evening'),
        for (var i = 1; i <= 4; i++) _e('n$i', at: _day(i + 10), band: 'evening'),
      ];
      final d = discoverySplit(events, now: now)!;
      expect(d.repeatTracks, 1, reason: 'the old track is a re-listen, not a discovery');
      expect(d.newTracks, 4);
    });

    test('stays SILENT below the sample where a share would mean anything', () {
      final now = _day(30);
      final events = [
        _e('a', at: _day(2), band: 'evening'),
        _e('b', at: _day(3), band: 'evening'),
      ];

      expect(discoverySplit(events, now: now), isNull);
    });

    test('nothing played at all is null, not 0% new', () {
      expect(discoverySplit(const [], now: _day(30)), isNull);
    });

    test('a track played ONLY outside the window does not count toward the split', () {
      final now = _day(30);
      final events = [
        _e('gone', at: DateTime(2026, 1, 1), band: 'evening'),
        for (var i = 1; i <= 5; i++) _e('n$i', at: _day(i + 10), band: 'evening'),
      ];
      final d = discoverySplit(events, now: now)!;
      expect(d.repeatTracks, 0, reason: 'it was not played this month, so it is not in the split');
      expect(d.newTracks, 5);
    });
  });

  group('the band chart can be weighted by time', () {
    test('time per band is accumulated alongside the counts', () {
      final events = [
        _e('a', at: _day(1, hour: 9), band: 'morning', positionMs: 20000),
        _e('b', at: _day(1, hour: 21), band: 'night', positionMs: 300000),
      ];
      final h = buildHistory(events, year: 2026, month: 10);

      expect(h.msByBand['morning'], 20000);
      expect(h.msByBand['night'], 300000);
    });
  });
}
