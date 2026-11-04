library;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/interruption_policy.dart';

InterruptionAction _decide({
  required bool begin,
  required AudioInterruptionType type,
  bool pausedByInterruption = false,
  bool wantPlay = true,
}) =>
    interruptionActionFor(
      begin: begin,
      type: type,
      pausedByInterruption: pausedByInterruption,
      wantPlay: wantPlay,
    );

void main() {
  group('an audio interruption begins', () {
    test('a duck lowers the level and does not stop the music', () {
      expect(_decide(begin: true, type: AudioInterruptionType.duck),
          InterruptionAction.duck);
    });

    test('a pause stops the music', () {
      expect(_decide(begin: true, type: AudioInterruptionType.pause),
          InterruptionAction.pause);
    });

    test('an UNKNOWN interruption is treated as a pause, not ignored', () {
      expect(_decide(begin: true, type: AudioInterruptionType.unknown),
          InterruptionAction.pause,
          reason: 'silence is the safe default for an interruption we cannot name');
    });

    test('a duck while the user had already paused changes nothing but the level',
        () {
      expect(
        _decide(
          begin: true,
          type: AudioInterruptionType.duck,
          wantPlay: false,
        ),
        InterruptionAction.duck,
      );
    });
  });

  group('an audio interruption ends', () {
    test('a duck restores the level the user chose', () {
      expect(_decide(begin: false, type: AudioInterruptionType.duck),
          InterruptionAction.restore,
          reason: 'a duck is a fraction of the user level, so the same fraction '
              'brings it back');
    });

    test('a pause resumes, but only what the interruption stopped', () {
      expect(
        _decide(
          begin: false,
          type: AudioInterruptionType.pause,
          pausedByInterruption: true,
          wantPlay: true,
        ),
        InterruptionAction.resume,
      );
    });

    test('a pause does NOT resume music the user had stopped', () {
      expect(
        _decide(
          begin: false,
          type: AudioInterruptionType.pause,
          pausedByInterruption: false,
          wantPlay: true,
        ),
        InterruptionAction.none,
        reason: 'the user paused before the call; the call ending is not a play command',
      );
    });

    test('a pause does not resume when the app no longer wants to play', () {
      expect(
        _decide(
          begin: false,
          type: AudioInterruptionType.pause,
          pausedByInterruption: true,
          wantPlay: false,
        ),
        InterruptionAction.none,
        reason: 'something stopped playback mid-call; the call ending must not undo it',
      );
    });

    test('the end of an UNKNOWN interruption is not a resume', () {
      expect(
        _decide(
          begin: false,
          type: AudioInterruptionType.unknown,
          pausedByInterruption: true,
          wantPlay: true,
        ),
        InterruptionAction.none,
        reason: 'too much would have to be true for an unnamed interruption to '
            'mean "play again"',
      );
    });
  });
}
