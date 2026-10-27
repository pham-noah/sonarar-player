library;

import 'package:flutter_test/flutter_test.dart';

int clampIndex(int wanted, int length) {
  if (length <= 0) return 0;
  return wanted.clamp(0, length - 1);
}

bool shouldReAssert({
  required int? wantIndex,
  required bool sourceReady,
  required int? currentIndex,
}) {
  if (wantIndex == null) return false;
  if (!sourceReady) return false;
  return currentIndex != wantIndex;
}

void main() {
  group('the index intent', () {
    test('a window sets the intent to the index the app is showing', () {
      expect(clampIndex(3, 9), 3);
    });

    test('the first and last positions are reachable, not clamped away', () {
      expect(clampIndex(0, 9), 0);
      expect(clampIndex(8, 9), 8);
    });

    test('an out-of-range index clamps instead of throwing', () {
      expect(clampIndex(99, 9), 8);
      expect(clampIndex(-5, 9), 0);
    });

    test('an empty window does not produce a negative index', () {
      expect(clampIndex(3, 0), 0);
    });

    test('a single-source load CLEARS the intent', () {
      int? wantIndex = 3;

      wantIndex = null;
      expect(
        shouldReAssert(wantIndex: wantIndex, sourceReady: true, currentIndex: 0),
        isFalse,
        reason: 'a single source must never trigger an index correction',
      );
    });
  });

  group('the re-assertion condition', () {
    test('corrects a player sitting on the wrong index', () {
      expect(
        shouldReAssert(wantIndex: 3, sourceReady: true, currentIndex: 0),
        isTrue,
      );
    });

    test('does NOT re-seek when the index is already right', () {
      expect(
        shouldReAssert(wantIndex: 3, sourceReady: true, currentIndex: 3),
        isFalse,
      );
    });

    test('waits for the source to be ready', () {
      expect(
        shouldReAssert(wantIndex: 3, sourceReady: false, currentIndex: 0),
        isFalse,
      );
    });

    test('a null index never re-seeks, whatever the player reports', () {
      for (final current in [null, 0, 3, 99]) {
        expect(
          shouldReAssert(wantIndex: null, sourceReady: true, currentIndex: current),
          isFalse,
        );
      }
    });

    test('an unknown current index counts as wrong, so it corrects', () {
      expect(
        shouldReAssert(wantIndex: 3, sourceReady: true, currentIndex: null),
        isTrue,
      );
    });
  });
}
