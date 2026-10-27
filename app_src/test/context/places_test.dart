library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/context/places.dart';

const double _lat0 = 10.8231;
const double _lon0 = 106.6297;

const double _mPerLatDeg = 111000.0;

double _lat(double metres) => _lat0 + metres / _mPerLatDeg;

PlaceAnchor _anchorAt(double metres, {double radiusM = 150}) => PlaceAnchor(
      latitude: _lat(metres),
      longitude: _lon0,
      radiusM: radiusM,
    );

void main() {
  group('a place is a set of spots, so a big one still matches', () {
    test('THE CAMPUS CASE: one anchor would fail, several cover it', () {
      final campus = NamedPlace(
        id: 'uni',
        name: 'University',

        anchors: [
          _anchorAt(0, radiusM: 200),
          _anchorAt(600, radiusM: 200),
          _anchorAt(1200, radiusM: 200),
        ],
      );

      expect(campus.contains(_lat(0), _lon0), isTrue);

      expect(campus.contains(_lat(600), _lon0), isTrue);

      expect(campus.contains(_lat(1200), _lon0), isTrue);

      expect(campus.contains(_lat(3000), _lon0), isFalse);
    });

    test('ANCHORS ARE CIRCLES, so the gap between two saved spots is a gap', () {
      final gapped = NamedPlace(
        id: 'uni',
        name: 'University',
        anchors: [
          _anchorAt(0, radiusM: 200),
          _anchorAt(600, radiusM: 200),
        ],
      );
      expect(
        gapped.contains(_lat(300), _lon0),
        isFalse,
        reason: '300m is outside both 200m circles — a genuine gap',
      );

      final overlapped = NamedPlace(
        id: 'uni',
        name: 'University',
        anchors: [
          _anchorAt(0, radiusM: 400),
          _anchorAt(600, radiusM: 400),
        ],
      );
      expect(
        overlapped.contains(_lat(300), _lon0),
        isTrue,
        reason: 'overlapping circles cover the middle',
      );
    });

    test('a single anchor still behaves like a single anchor', () {
      final home = NamedPlace(
        id: 'home',
        name: 'Home',
        anchors: [_anchorAt(0)],
      );
      expect(home.contains(_lat(0), _lon0), isTrue);
      expect(home.contains(_lat(100), _lon0), isTrue);
      expect(home.contains(_lat(300), _lon0), isFalse);
    });

    test('the radius is per anchor, not per place', () {
      final place = NamedPlace(
        id: 'mixed',
        name: 'Mixed',
        anchors: [
          _anchorAt(0, radiusM: 50),
          _anchorAt(1000, radiusM: 800),
        ],
      );
      expect(place.contains(_lat(60), _lon0), isFalse, reason: 'outside the tight one');
      expect(place.contains(_lat(1000), _lon0), isTrue);
      expect(place.contains(_lat(1700), _lon0), isTrue, reason: 'inside the wide one');
    });
  });

  group('the book picks the place you are actually in', () {
    test('nearest wins when two both match', () {
      final book = PlaceBook([
        NamedPlace(id: 'uni', name: 'University', anchors: [_anchorAt(0, radiusM: 2000)]),
        NamedPlace(id: 'gym', name: 'Gym', anchors: [_anchorAt(100, radiusM: 120)]),
      ]);

      expect(book.placeAt(_lat(100), _lon0)?.id, 'gym',
          reason: 'standing in the gym should not answer "university"');

      expect(book.placeAt(_lat(900), _lon0)?.id, 'uni');

      expect(book.placeAt(_lat(9000), _lon0), isNull);
    });

    test('no places means no match rather than a crash', () {
      expect(PlaceBook.empty.placeAt(_lat0, _lon0), isNull);
      expect(PlaceBook.empty.isEmpty, isTrue);
    });

    test('being nowhere returns null, which is a real answer', () {
      final book = PlaceBook([
        NamedPlace(id: 'home', name: 'Home', anchors: [_anchorAt(0)]),
      ]);
      expect(book.placeAt(_lat(5000), _lon0), isNull);
    });
  });

  group('adding a spot grows the place', () {
    test('standing somewhere new adds coverage instead of replacing it', () {
      var book = PlaceBook([
        NamedPlace(id: 'uni', name: 'University', anchors: [_anchorAt(0, radiusM: 200)]),
      ]);
      expect(book.placeAt(_lat(800), _lon0), isNull);

      book = book.withAnchor('uni', _anchorAt(800, radiusM: 200));
      expect(book.placeAt(_lat(800), _lon0)?.id, 'uni');

      expect(book.placeAt(_lat(0), _lon0)?.id, 'uni');
    });

    test('an unknown id changes nothing rather than inventing a place', () {
      final book = PlaceBook([
        NamedPlace(id: 'uni', name: 'University', anchors: [_anchorAt(0)]),
      ]);
      final after = book.withAnchor('nope', _anchorAt(100));
      expect(after.length, 1);
      expect(after.byId('nope'), isNull);
    });
  });

  group('storage rejects what it cannot use', () {
    test('round-trips through JSON', () {
      final book = PlaceBook([
        NamedPlace(
          id: 'uni',
          name: 'University',
          playlist: 'uni mix',
          anchors: [_anchorAt(0, radiusM: 300), _anchorAt(600)],
        ),
      ]);
      final back = PlaceBook.decode(book.encode());
      expect(back.length, 1);
      final p = back.byId('uni')!;
      expect(p.name, 'University');
      expect(p.playlist, 'uni mix');
      expect(p.anchors.length, 2);
      expect(p.anchors.first.radiusM, 300);
    });

    test('a place with no anchors is dropped, not kept as inert', () {
      final book = PlaceBook.decode(
        '{"places":[{"id":"ghost","name":"Ghost","anchors":[]}]}',
      );
      expect(book.isEmpty, isTrue);
    });

    test('null island and out-of-range coordinates are refused', () {
      final book = PlaceBook.decode(
        '{"places":['
        '{"id":"a","name":"A","anchors":[{"lat":0,"lon":0}]},'
        '{"id":"b","name":"B","anchors":[{"lat":999,"lon":0}]},'
        '{"id":"c","name":"C","anchors":[{"lat":10.8,"lon":106.6}]}'
        ']}',
      );

      expect(book.byId('a'), isNull, reason: 'null island');
      expect(book.byId('b'), isNull, reason: 'latitude 999');
      expect(book.byId('c'), isNotNull);
    });

    test('a nonsense radius is clamped, not obeyed', () {
      final one = PlaceAnchor.fromJson(
        {'lat': 10.8, 'lon': 106.6, 'radius_m': 999999},
      );
      expect(one!.radiusM, 5000);
      final tiny = PlaceAnchor.fromJson(
        {'lat': 10.8, 'lon': 106.6, 'radius_m': 0.5},
      );
      expect(tiny!.radiusM, 10);
    });

    test('a malformed file yields no places rather than throwing', () {
      for (final bad in ['', 'not json', '{}', '{"places":"nope"}', '[]']) {
        expect(PlaceBook.decode(bad).isEmpty, isTrue, reason: 'accepted "$bad"');
      }
    });
  });
}
