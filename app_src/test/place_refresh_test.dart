library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/context/place_refresh.dart';

void main() {
  group('when to ask where we are again', () {
    final t0 = DateTime(2026, 10, 3, 12);

    test('a first ask is always due', () {
      expect(isPlaceRefreshDue(lastAsked: null, now: t0), isTrue);
    });

    test('too soon is not due', () {
      expect(
        isPlaceRefreshDue(lastAsked: t0, now: t0.add(const Duration(minutes: 4))),
        isFalse,
      );
    });

    test('the interval exactly is due', () {
      expect(
        isPlaceRefreshDue(lastAsked: t0, now: t0.add(const Duration(minutes: 5))),
        isTrue,
      );
    });

    test('a long gap is due', () {
      expect(
        isPlaceRefreshDue(lastAsked: t0, now: t0.add(const Duration(hours: 2))),
        isTrue,
      );
    });
  });

  group('what a new fix means', () {
    test('the same place is ignored — no switch, no weather refetch', () {
      expect(
        placeActionFor(
          previousPlaceId: 'home',
          newPlaceId: 'home',
          trustworthy: true,
          moved: false,
        ),
        PlaceAction.ignore,
      );
    });

    test('a different place on a TRUSTWORTHY fix switches the music', () {
      expect(
        placeActionFor(
          previousPlaceId: 'home',
          newPlaceId: 'cafe',
          trustworthy: true,
          moved: true,
        ),
        PlaceAction.publishAndSwitch,
      );
    });

    test('a different place on a LOOSE fix publishes but does NOT switch', () {
      expect(
        placeActionFor(
          previousPlaceId: 'home',
          newPlaceId: 'cafe',
          trustworthy: false,
          moved: true,
        ),
        PlaceAction.publishOnly,
      );
    });

    test('arriving at NO saved place, having moved, is TRAVELLING', () {
      expect(
        placeActionFor(
          previousPlaceId: 'home',
          newPlaceId: null,
          trustworthy: true,
          moved: true,
        ),
        PlaceAction.travelling,
      );
    });

    test('losing the fix while standing still says nothing', () {
      expect(
        placeActionFor(
          previousPlaceId: 'home',
          newPlaceId: null,
          trustworthy: false,
          moved: false,
        ),
        PlaceAction.ignore,
      );
    });

    test('starting FROM nowhere into a place still switches', () {
      expect(
        placeActionFor(
          previousPlaceId: null,
          newPlaceId: 'home',
          trustworthy: true,
          moved: true,
        ),
        PlaceAction.publishAndSwitch,
      );
    });
  });

  group('are we walking', () {
    test('a walk is a walk', () {
      expect(looksLikeWalking(1.4), isTrue);
    });

    test('standing still is not walking', () {
      expect(looksLikeWalking(0.1), isFalse);
      expect(looksLikeWalking(0.0), isFalse);
    });

    test('a car is not walking', () {
      expect(looksLikeWalking(9.0), isFalse);
    });

    test('a fast walk still counts', () {
      expect(looksLikeWalking(2.0), isTrue);
    });

    test('no reading is not walking rather than an error', () {
      expect(looksLikeWalking(null), isFalse);
    });

    test('speed comes from two fixes: 420m in 300s is a walk', () {
      final v = speedMetresPerSecond(
        fromLat: 60.0000,
        fromLon: 24.0000,
        toLat: 60.00378,
        toLon: 24.0000,
        seconds: 300,
      );
      expect(v, isNotNull);
      expect(v, closeTo(1.4, 0.2));
      expect(looksLikeWalking(v), isTrue);
    });

    test('a missing fix gives no speed rather than zero', () {
      expect(
        speedMetresPerSecond(
          fromLat: null,
          fromLon: 24.0,
          toLat: 60.0,
          toLon: 24.0,
          seconds: 300,
        ),
        isNull,
      );
    });

    test('zero seconds is refused rather than dividing by zero', () {
      expect(
        speedMetresPerSecond(
          fromLat: 60.0,
          fromLon: 24.0,
          toLat: 60.001,
          toLon: 24.0,
          seconds: 0,
        ),
        isNull,
      );
    });
  });

  group('did we actually move', () {
    test('a jitter while sitting still is NOT movement', () {
      expect(
        hasMoved(
          fromLat: 60.0000,
          fromLon: 24.0000,
          toLat: 60.0002,
          toLon: 24.0000,
        ),
        isFalse,
      );
    });

    test('a real walk between polls IS movement', () {
      expect(
        hasMoved(
          fromLat: 60.0000,
          fromLon: 24.0000,
          toLat: 60.00378,
          toLon: 24.0000,
        ),
        isTrue,
      );
    });

    test('no fix at either end is not movement', () {
      expect(hasMoved(fromLat: null, fromLon: null, toLat: 60.0, toLon: 24.0),
          isFalse);
    });
  });
}
