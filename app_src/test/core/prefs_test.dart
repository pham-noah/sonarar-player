library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/prefs.dart';

void main() {
  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('prefs');
    file = File('${tmp.path}/prefs.json');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('a fresh install gets the documented defaults', () {
    test('and they are what the code says they are', () {
      const p = AppPrefs.initial;

      expect(p.resumeOnLaunch, isFalse);
      expect(p.crossfadeSeconds, 0);
      expect(p.gaplessPlayback, isTrue);
      expect(p.sleepTimerMinutes, 30);
      expect(p.skipThresholdSeconds, 10);
      expect(p.weatherRefreshMinutes, 30);
      expect(p.allowNetwork, isTrue);
    });

    test('no file at all loads as the defaults, not as an error', () async {
      final got = await PrefsStore(file).load();
      expect(got.resumeOnLaunch, AppPrefs.initial.resumeOnLaunch);
      expect(got.crossfadeSeconds, AppPrefs.initial.crossfadeSeconds);
    });

    test('a file appears only when something is saved', () async {
      expect(file.existsSync(), isFalse);
      await PrefsStore(file).save(const AppPrefs(resumeOnLaunch: true));
      expect(file.existsSync(), isTrue);
    });
  });

  group('an OLDER file still loads', () {
    test('a file with only one key keeps defaults for the rest', () async {
      file.writeAsStringSync('{"crossfade_seconds": 4}');
      final got = await PrefsStore(file).load();

      expect(got.crossfadeSeconds, 4);
      expect(got.resumeOnLaunch, AppPrefs.initial.resumeOnLaunch);
      expect(got.gaplessPlayback, AppPrefs.initial.gaplessPlayback);
      expect(got.allowNetwork, AppPrefs.initial.allowNetwork);
    });

    test('an empty object is the defaults', () async {
      file.writeAsStringSync('{}');
      final got = await PrefsStore(file).load();
      expect(got.sleepTimerMinutes, AppPrefs.initial.sleepTimerMinutes);
    });
  });

  group('a broken file never stops the launch', () {
    test('truncated JSON gives the defaults', () async {
      file.writeAsStringSync('{"crossfade_sec');
      final got = await PrefsStore(file).load();
      expect(got.crossfadeSeconds, AppPrefs.initial.crossfadeSeconds);
    });

    test('a non-object gives the defaults', () async {
      for (final bad in ['[]', '"nope"', '42', 'null']) {
        file.writeAsStringSync(bad);
        final got = await PrefsStore(file).load();
        expect(got.gaplessPlayback, AppPrefs.initial.gaplessPlayback,
            reason: 'accepted $bad');
      }
    });

    test('a WRONG TYPE falls back rather than throwing on a cast', () async {
      file.writeAsStringSync(
        '{"crossfade_seconds":"loud","resume_on_launch":"yes","gapless_playback":1}',
      );
      final got = await PrefsStore(file).load();
      expect(got.crossfadeSeconds, AppPrefs.initial.crossfadeSeconds);
      expect(got.resumeOnLaunch, AppPrefs.initial.resumeOnLaunch);
      expect(got.gaplessPlayback, AppPrefs.initial.gaplessPlayback);
    });
  });

  group('the ranges are enforced, not merely offered', () {
    test('crossfade is clamped to the slider it is shown on', () {
      expect(const AppPrefs(crossfadeSeconds: 900).copyWith().crossfadeSeconds, 12);
      expect(const AppPrefs(crossfadeSeconds: -5).copyWith().crossfadeSeconds, 0);
    });

    test('a zero-second sleep timer is impossible', () {
      expect(const AppPrefs(sleepTimerMinutes: 0).copyWith().sleepTimerMinutes, 5);
      expect(const AppPrefs(sleepTimerMinutes: 9999).copyWith().sleepTimerMinutes, 180);
    });

    test('a 1-second skip threshold is impossible', () {
      expect(const AppPrefs(skipThresholdSeconds: 1).copyWith().skipThresholdSeconds, 3);
    });

    test('the durations are derived from the numbers, not duplicated', () {
      const p = AppPrefs(crossfadeSeconds: 6, sleepTimerMinutes: 45);
      expect(p.crossfade, const Duration(seconds: 6));
      expect(p.sleepTimer, const Duration(minutes: 45));
    });
  });

  group('round trip', () {
    test('every field survives a save and load', () async {
      const p = AppPrefs(
        resumeOnLaunch: true,
        crossfadeSeconds: 7,
        gaplessPlayback: false,
        sleepTimerMinutes: 60,
        skipThresholdSeconds: 20,
        weatherRefreshMinutes: 90,
        allowNetwork: false,
      );
      await PrefsStore(file).save(p);
      final got = await PrefsStore(file).load();

      expect(got.resumeOnLaunch, isTrue);
      expect(got.crossfadeSeconds, 7);
      expect(got.gaplessPlayback, isFalse);
      expect(got.sleepTimerMinutes, 60);
      expect(got.skipThresholdSeconds, 20);
      expect(got.weatherRefreshMinutes, 90);
      expect(got.allowNetwork, isFalse);
    });

    test('copyWith changes one field and leaves the rest', () {
      const p = AppPrefs(crossfadeSeconds: 3, allowNetwork: false);
      final q = p.copyWith(resumeOnLaunch: true);
      expect(q.resumeOnLaunch, isTrue);
      expect(q.crossfadeSeconds, 3);
      expect(q.allowNetwork, isFalse);
    });
  });
}
