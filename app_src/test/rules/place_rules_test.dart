library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/context/places.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/place_rules.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin_policy.dart';

const double _lat = 10.8231;
const double _lon = 106.6297;

NamedPlace _place({
  required String id,
  String? playlist,
  int anchors = 1,
}) =>
    NamedPlace(
      id: id,
      name: id.toUpperCase(),
      playlist: playlist,
      anchors: [
        for (var i = 0; i < anchors; i++)
          PlaceAnchor(latitude: _lat + i * 0.001, longitude: _lon, radiusM: 200),
      ]);

PlaylistContext _ctx({String? placeId, ContextBand band = ContextBand.afternoon}) =>
    PlaylistContext(
      band: band,
      whereabouts: placeId == 'home' ? Whereabouts.home : Whereabouts.unknown,
      sky: Sky.unknown,
      localHour: 15,
      placeId: placeId);

void main() {
  group('a place with a playlist BECOMES a rule', () {
    test('saving the place is the whole act', () {
      final rules = placeRules(PlaceBook([
        _place(id: 'gym', playlist: 'Gym Metal'),
      ]));

      expect(rules.length, 1);
      expect(rules.first.placeId, 'gym');
      expect(rules.first.playlist, 'Gym Metal');
    });

    test('and it MATCHES when you are there', () {
      final rules = ContextRules(placeRules(PlaceBook([
        _place(id: 'gym', playlist: 'Gym Metal'),
      ])));

      final atGym = rules.firstMatch(_ctx(placeId: 'gym'));
      expect(atGym?.playlist, 'Gym Metal');

      expect(rules.firstMatch(_ctx(placeId: 'home')), isNull);
      expect(rules.firstMatch(_ctx()), isNull);
    });

    test('a place with NO playlist produces no rule', () {
      expect(placeRules(PlaceBook([_place(id: 'uni')])), isEmpty);
    });

    test('a blank playlist is treated as none, not as a rule naming ""', () {
      expect(placeRules(PlaceBook([_place(id: 'a', playlist: '   ')])), isEmpty);
    });

    test('a place with no anchors never becomes a rule', () {
      final broken = PlaceBook([
        _place(id: 'ghost', playlist: 'Nowhere'),
      ]);
      expect(broken.byId('ghost'), isNotNull, reason: 'it has one anchor');

      final dropped = PlaceBook.decode(
        '{"places":[{"id":"ghost","name":"Ghost","playlist":"X","anchors":[]}]}');
      expect(dropped.isEmpty, isTrue);
      expect(placeRules(dropped), isEmpty);
    });
  });

  group('where it ranks', () {
    test('BELOW battle mode and Dark Hour', () {
      final derived = placeRules(PlaceBook([_place(id: 'gym', playlist: 'G')]));
      for (final r in derived) {
        expect(r.priority, lessThan(78));
      }
    });

    test('ABOVE an ordinary time-band rule', () {
      final written = ContextRules([
        ContextRule(id: 'afternoon', priority: 10, band: ContextBand.afternoon, playlist: 'Afternoon'),
      ]);
      final all = withPlaceRules(written, PlaceBook([_place(id: 'gym', playlist: 'G')]));

      expect(all.firstMatch(_ctx(placeId: 'gym'))?.playlist, 'G');
    });

    test('a HAND-WRITTEN rule at the same priority wins', () {
      final written = ContextRules([
        ContextRule(id: 'mine', priority: kPlaceRulePriority, playlist: 'My Choice'),
      ]);
      final all = withPlaceRules(written, PlaceBook([_place(id: 'gym', playlist: 'G')]));
      expect(all.firstMatch(_ctx(placeId: 'gym'))?.playlist, 'My Choice');
    });
  });

  group('the derived rules are never stored', () {
    test('withPlaceRules returns only what runs; written stays clean', () {
      final written = ContextRules([
        ContextRule(id: 'battle', priority: 80, playlist: 'B'),
      ]);
      final all = withPlaceRules(written, PlaceBook([_place(id: 'gym', playlist: 'G')]));

      expect(all.length, 2, reason: 'both run');
      expect(written.length, 1, reason: 'only the hand-written one is stored');
      expect(written.encode(), isNot(contains('place-')));
    });

    test('deleting the place removes its rule, because it was never stored', () {
      final written = ContextRules.empty;
      final withGym = withPlaceRules(written, PlaceBook([_place(id: 'gym', playlist: 'G')]));
      expect(withGym.firstMatch(_ctx(placeId: 'gym')), isNotNull);

      final afterDelete = withPlaceRules(written, PlaceBook.empty);
      expect(afterDelete.firstMatch(_ctx(placeId: 'gym')), isNull);
      expect(afterDelete.isEmpty, isTrue);
    });

    test('no places means the written rules are returned untouched', () {
      final written = ContextRules([
        ContextRule(id: 'a', priority: 5, playlist: 'A'),
      ]);
      final same = withPlaceRules(written, PlaceBook.empty);
      expect(same.length, written.length);
      expect(same.firstMatch(_ctx()), isNotNull);
    });

    test('renaming a place keeps its rule pointed at the same place', () {
      final book = PlaceBook([
        NamedPlace(
          id: 'uni',
          name: 'University of Somewhere',
          playlist: 'Campus',
          anchors: const [
            PlaceAnchor(latitude: _lat, longitude: _lon, radiusM: 400),
          ]),
      ]);
      final rules = ContextRules(placeRules(book));
      expect(rules.firstMatch(_ctx(placeId: 'uni'))?.playlist, 'Campus');
    });
  });

  group('a place does not repaint the app', () {
    test('the derived rule sets no theme', () {
      final rules = placeRules(PlaceBook([_place(id: 'gym', playlist: 'G')]));
      expect(rules.first.theme, isNull);
    });
  });
}
