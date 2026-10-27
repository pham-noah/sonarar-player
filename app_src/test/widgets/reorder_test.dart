library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/widgets/reorder.dart';

void main() {
  const h = 80.0;

  group('where a dragged row lands', () {
    test('no travel means no move', () {
      expect(reorderTarget(from: 2, travelled: 0, rowHeight: h, length: 5), 2);
    });

    test('a small nudge does not reorder', () {
      expect(reorderTarget(from: 2, travelled: -20, rowHeight: h, length: 5), 2);
    });

    test('up past one row moves it one place earlier', () {
      expect(reorderTarget(from: 2, travelled: -h, rowHeight: h, length: 5), 1);
    });

    test('down past one row moves it one place later', () {
      expect(reorderTarget(from: 2, travelled: h, rowHeight: h, length: 5), 3);
    });

    test('two rows of travel moves two places', () {
      expect(reorderTarget(from: 3, travelled: -2 * h, rowHeight: h, length: 6), 1);
    });

    test('it cannot be dragged off the top', () {
      expect(reorderTarget(from: 1, travelled: -999, rowHeight: h, length: 5), 0);
    });

    test('it cannot be dragged off the bottom', () {
      expect(reorderTarget(from: 1, travelled: 999, rowHeight: h, length: 5), 4);
    });

    test('a zero row height does not divide by zero', () {
      expect(reorderTarget(from: 2, travelled: -100, rowHeight: 0, length: 5), 2);
    });
  });

  group('which rows step aside, and which way', () {
    test('the dragged row is never displaced — it is the one being held', () {
      expect(displacementFor(index: 2, from: 2, to: 4, rowHeight: h), 0);
    });

    test('dragging DOWN: the rows passed step up to close the gap', () {
      expect(displacementFor(index: 2, from: 1, to: 3, rowHeight: h), -h);
      expect(displacementFor(index: 3, from: 1, to: 3, rowHeight: h), -h);

      expect(displacementFor(index: 0, from: 1, to: 3, rowHeight: h), 0);
      expect(displacementFor(index: 4, from: 1, to: 3, rowHeight: h), 0);
    });

    test('dragging UP: the rows passed step down to open a gap', () {
      expect(displacementFor(index: 1, from: 3, to: 1, rowHeight: h), h);
      expect(displacementFor(index: 2, from: 3, to: 1, rowHeight: h), h);
      expect(displacementFor(index: 0, from: 3, to: 1, rowHeight: h), 0);
      expect(displacementFor(index: 4, from: 3, to: 1, rowHeight: h), 0);
    });

    test('no move at all displaces nobody', () {
      for (var i = 0; i < 5; i++) {
        expect(displacementFor(index: i, from: 2, to: 2, rowHeight: h), 0);
      }
    });

    test('exactly one row is affected per row crossed', () {
      var moved = 0;
      for (var i = 0; i < 5; i++) {
        if (displacementFor(index: i, from: 0, to: 2, rowHeight: h) != 0) moved++;
      }
      expect(moved, 2);
    });
  });
}
