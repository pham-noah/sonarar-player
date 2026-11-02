import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The notices ship twice: `NOTICE.md` at the repository root is the copy a
/// reader finds, and `assets/legal/NOTICE.md` is the copy the app loads in its
/// licence dialog. Two files with one job drift, and the one that drifts is
/// always the one the user sees.
void main() {
  test('the shipped notices and the repository notices are the same file', () {
    final shipped = File('assets/legal/NOTICE.md');
    final readme = File('../NOTICE.md');

    expect(shipped.existsSync(), isTrue,
        reason: 'assets/legal/NOTICE.md is loaded by legal.dart');
    expect(readme.existsSync(), isTrue,
        reason: '../NOTICE.md is the copy the repository shows');

    expect(
      shipped.readAsStringSync(),
      equals(readme.readAsStringSync()),
      reason: 'copy the edited file over the other one, whichever changed',
    );
  });
}
