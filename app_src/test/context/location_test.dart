library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/context/location_service.dart';

void main() {
  group('distanceMetres', () {
    const homeLat = 10.8231;
    const homeLon = 106.6297;

    test('the same point is zero', () {
      expect(
        distanceMetres(lat1: homeLat, lon1: homeLon, lat2: homeLat, lon2: homeLon),
        closeTo(0.0, 0.001),
      );
    });

    test('a known separation matches an independent reference', () {
      expect(
        distanceMetres(
          lat1: homeLat,
          lon1: homeLon,
          lat2: homeLat,
          lon2: homeLon + 0.22,
        ),
        closeTo(24030, 30),
      );

      expect(
        distanceMetres(
          lat1: homeLat,
          lon1: homeLon,
          lat2: homeLat + 0.05,
          lon2: homeLon,
        ),
        closeTo(5560, 30),
      );
    });

    test('GPS-scale distances are right too', () {
      expect(
        distanceMetres(
          lat1: homeLat,
          lon1: homeLon,
          lat2: homeLat + 0.001,
          lon2: homeLon,
        ),
        closeTo(111, 2),
        reason: '~111m is 0.001 degrees of latitude',
      );
    });

    test('a missing square root would flatten the world, and must not', () {
      expect(
        distanceMetres(
          lat1: homeLat,
          lon1: homeLon,
          lat2: 21.0285,
          lon2: 105.8542,
        ),
        closeTo(1137800, 2000),
        reason: 'Hanoi is ~1138km away',
      );
    });

    test('antipodal points do not produce NaN', () {
      final d = distanceMetres(
        lat1: homeLat,
        lon1: homeLon,
        lat2: -homeLat,
        lon2: homeLon - 180,
      );
      expect(d.isNaN, isFalse);
      expect(d, closeTo(20015000, 50000));
    });
  });

  group('a named place matches by radius, not by distance alone', () {
    const home = (lat: 10.8231, lon: 106.6297);

    bool atPlace({
      required double lat,
      required double lon,
      double radiusM = kDefaultPlaceRadiusM,
    }) =>
        distanceMetres(lat1: home.lat, lon1: home.lon, lat2: lat, lon2: lon) <=
        radiusM;

    test('standing still is the place', () {
      expect(atPlace(lat: home.lat, lon: home.lon), isTrue);
    });

    test('the default radius covers GPS error but not the next street', () {
      expect(atPlace(lat: home.lat + 0.001, lon: home.lon), isTrue);

      expect(atPlace(lat: home.lat + 0.002, lon: home.lon), isFalse);
    });

    test('a campus needs a bigger radius than a flat, which is why it is per-place', () {
      expect(atPlace(lat: home.lat + 0.006, lon: home.lon), isFalse);
      expect(
        atPlace(lat: home.lat + 0.006, lon: home.lon, radiusM: 1000),
        isTrue,
      );
    });
  });
}
