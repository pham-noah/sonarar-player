library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/playback/loop_controller.dart';
import 'package:sonarar/playback/loop_points.dart';

LoopPoints _marked() => const LoopPoints(
      trackId: 'tartarus',
      introEnd: Duration(seconds: 40),
      loopStart: Duration(seconds: 40),
      loopEnd: Duration(seconds: 130),
      loopCount: 2,
      fade: Duration(seconds: 8),
    );

void main() {
  group('an unmarked track is provably unaffected', () {
    test('no loop points means no action, ever', () {
      final c = LoopController();
      for (final seconds in [0, 1, 39, 40, 130, 500, 100000]) {
        expect(
          c.decide(
            position: Duration(seconds: seconds),
            duration: const Duration(minutes: 9),
          ),
          LoopAction.none,
          reason: 'unmarked track acted at ${seconds}s',
        );
      }
      expect(c.hasLoop, isFalse);
    });

    test('an intro-only marking is not a loop', () {
      const introOnly = LoopPoints(
        trackId: 't',
        introEnd: Duration(seconds: 30),
      );
      final c = LoopController(points: introOnly);
      expect(c.hasLoop, isFalse);
      expect(
        c.decide(position: const Duration(minutes: 10), duration: const Duration(minutes: 10)),
        LoopAction.none,
      );
    });

    test('a loop region with a zero count does not repeat', () {
      const zero = LoopPoints(
        trackId: 't',
        loopStart: Duration(seconds: 10),
        loopEnd: Duration(seconds: 60),
        loopCount: 0,
      );
      final c = LoopController(points: zero);
      expect(c.hasLoop, isFalse);
    });

    test('a loop region whose end precedes its start is rejected', () {
      const backwards = LoopPoints(
        trackId: 't',
        loopStart: Duration(seconds: 60),
        loopEnd: Duration(seconds: 10),
        loopCount: 3,
      );
      expect(backwards.hasLoop, isFalse);
    });
  });

  group('a marked track repeats exactly as many times as marked', () {
    test('two loops, then a fade, and no more', () {
      final c = LoopController(points: _marked());
      const dur = Duration(minutes: 9);
      const end = Duration(seconds: 130);

      expect(c.decide(position: const Duration(seconds: 129), duration: dur),
          LoopAction.none);

      expect(c.decide(position: end, duration: dur), LoopAction.seekToLoopStart);
      expect(c.completedLoops, 1);

      expect(c.decide(position: end, duration: dur), LoopAction.seekToLoopStart);
      expect(c.completedLoops, 2);

      expect(c.decide(position: end, duration: dur), LoopAction.fadeOut);
    });

    test('the fade is asked for exactly once', () {
      final c = LoopController(points: _marked());
      const dur = Duration(minutes: 9);
      const end = Duration(seconds: 130);
      c.decide(position: end, duration: dur);
      c.decide(position: end, duration: dur);
      expect(c.decide(position: end, duration: dur), LoopAction.fadeOut);
      expect(c.decide(position: end, duration: dur), LoopAction.none);
      expect(c.decide(position: const Duration(seconds: 131), duration: dur),
          LoopAction.none);
    });

    test('a non-looping moment inside the region is inert', () {
      final c = LoopController(points: _marked());
      const dur = Duration(minutes: 9);
      for (final s in [41, 60, 90, 129]) {
        expect(c.decide(position: Duration(seconds: s), duration: dur),
            LoopAction.none,
            reason: 'acted mid-region at ${s}s');
      }
      expect(c.completedLoops, 0);
    });

    test('a count of one means one repeat, not one play', () {
      final c = LoopController(
          points: const LoopPoints(
        trackId: 't',
        loopStart: Duration(seconds: 10),
        loopEnd: Duration(seconds: 60),
        loopCount: 1,
      ));
      const dur = Duration(minutes: 3);
      const end = Duration(seconds: 60);
      expect(c.decide(position: end, duration: dur), LoopAction.seekToLoopStart);
      expect(c.decide(position: end, duration: dur), LoopAction.fadeOut);
    });
  });

  group('the intro trim applies to replays only', () {
    test('a first play starts at zero', () {
      final c = LoopController(points: _marked());
      expect(c.firstPlayStart, Duration.zero);
    });

    test('a replay starts past the lead-in', () {
      final c = LoopController(points: _marked());
      expect(c.resumePosition, const Duration(seconds: 40));
    });

    test('a track with no lead-in replays from the start', () {
      final c = LoopController(
          points: const LoopPoints(
        trackId: 't',
        loopStart: Duration(seconds: 10),
        loopEnd: Duration(seconds: 60),
        loopCount: 1,
      ));
      expect(c.resumePosition, Duration.zero);
    });
  });

  group('reset is per play, not per session', () {
    test('reset restores the full loop budget', () {
      final c = LoopController(points: _marked());
      const dur = Duration(minutes: 9);
      const end = Duration(seconds: 130);
      c.decide(position: end, duration: dur);
      c.decide(position: end, duration: dur);
      c.decide(position: end, duration: dur);
      expect(c.completedLoops, 2);

      c.reset();
      expect(c.completedLoops, 0);

      expect(c.decide(position: end, duration: dur), LoopAction.seekToLoopStart);
      expect(c.decide(position: end, duration: dur), LoopAction.seekToLoopStart);
      expect(c.decide(position: end, duration: dur), LoopAction.fadeOut);
    });
  });

  group('markings survive a round trip, and corruption is survivable', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('loops'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a saved marking comes back identical', () async {
      final store = LoopPointStore(File('${dir.path}/loops.json'));
      await store.save({'tartarus': _marked()});

      final back = await store.load();
      final p = back['tartarus']!;
      expect(p.introEnd, const Duration(seconds: 40));
      expect(p.loopStart, const Duration(seconds: 40));
      expect(p.loopEnd, const Duration(seconds: 130));
      expect(p.loopCount, 2);
      expect(p.fade, const Duration(seconds: 8));
    });

    test('a truncated file reads as no markings rather than crashing', () async {
      final f = File('${dir.path}/loops.json');
      f.writeAsStringSync('[{"track_id":"tartarus","loop_st');
      expect(await LoopPointStore(f).load(), isEmpty);
    });

    test('a missing file reads as no markings', () async {
      expect(await LoopPointStore(File('${dir.path}/none.json')).load(), isEmpty);
    });

    test('an entry with no track_id is skipped, not fatal', () async {
      final f = File('${dir.path}/loops.json');
      f.writeAsStringSync(jsonEncode([
        {'loop_start_ms': 1000},
        {'track_id': 'good', 'loop_start_ms': 1000, 'loop_end_ms': 2000, 'loop_count': 1},
      ]));
      final back = await LoopPointStore(f).load();
      expect(back.keys, ['good']);
    });
  });
}
