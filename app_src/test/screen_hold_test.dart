library;

import 'package:flutter_test/flutter_test.dart';

bool screenHoldWanted({required bool playing, required bool inFront}) =>
    playing && inFront;

void main() {
  group('the screen is held only while music plays AND the app is in front', () {
    test('playing, in front -> hold', () {
      expect(screenHoldWanted(playing: true, inFront: true), isTrue);
    });

    test('NOT playing, in front -> no hold', () {
      expect(screenHoldWanted(playing: false, inFront: true), isFalse);
    });

    test('PLAYING, BACKGROUNDED -> no hold', () {
      expect(screenHoldWanted(playing: true, inFront: false), isFalse);
    });

    test('neither -> no hold', () {
      expect(screenHoldWanted(playing: false, inFront: false), isFalse);
    });
  });

  group('the transitions that matter', () {
    test('pausing WHILE on screen releases it', () {
      expect(screenHoldWanted(playing: true, inFront: true), isTrue);
      expect(screenHoldWanted(playing: false, inFront: true), isFalse);
    });

    test('backgrounding WHILE playing releases it', () {
      expect(screenHoldWanted(playing: true, inFront: true), isTrue);
      expect(screenHoldWanted(playing: true, inFront: false), isFalse);
    });

    test('resuming WHILE still playing re-acquires it', () {
      expect(screenHoldWanted(playing: true, inFront: false), isFalse);
      expect(screenHoldWanted(playing: true, inFront: true), isTrue);
    });
  });
}
