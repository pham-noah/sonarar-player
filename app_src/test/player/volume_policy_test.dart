library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/player/volume_policy.dart';

void main() {
  group('a duck is a fraction of the user\'s level, never a fixed value', () {
    test('at full it is the familiar 0.4', () {
      expect(ducked(1.0), closeTo(0.4, 1e-9));
    });

    test('at 20% it QUIETS rather than jumping up', () {
      final out = ducked(0.2);
      expect(out, lessThan(0.2));
      expect(out, closeTo(0.08, 1e-9));
    });

    test('muted stays muted', () {
      expect(ducked(0.0), 0.0);
    });
  });

  group('restoring goes back to the USER, not to full', () {
    test('a muted player is restored to silence, not to 1.0', () {
      expect(restoredLevel(0.0), 0.0,
          reason: 'the app says muted; the engine must agree or the app lies');
    });

    test('any level comes back exactly', () {
      for (final v in [0.0, 0.18, 0.5, 1.0]) {
        expect(restoredLevel(v), v);
      }
    });
  });

  test('neither can leave the valid range', () {
    expect(restoredLevel(1.7), 1.0);
    expect(restoredLevel(-0.5), 0.0);
    expect(ducked(3.0), lessThanOrEqualTo(1.0));
    expect(ducked(-1.0), 0.0);
  });
}
