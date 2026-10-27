library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin_policy.dart';

PlaylistContext _ctx({
  String? placeId,
  bool hasReading = true,
  ContextBand band = ContextBand.afternoon,

  bool commuting = false,
}) =>
    PlaylistContext(
      band: band,
      whereabouts: commuting
          ? Whereabouts.commuting
          : (!hasReading
              ? Whereabouts.unknown
              : (placeId == 'home'
                  ? Whereabouts.home

                  : (placeId != null ? Whereabouts.atPlace : Whereabouts.away))),
      sky: Sky.unknown,
      localHour: 15,
      placeId: placeId,
    );
ContextRule _commute() => ContextRule(
      id: 'commuting',
      priority: 66,
      place: PlaceWant.anywhere,
      playlist: 'Commuting');

void main() {
  group('the commuting rule fires only when genuinely between places', () {
    test('it fires when a reading arrived and matched nothing', () {
      final rules = ContextRules([_commute()]);
      expect(rules.firstMatch(_ctx(commuting: true))?.playlist, 'Commuting');
    });

    test('it does NOT fire when there is no reading at all', () {
      final rules = ContextRules([_commute()]);
      expect(rules.firstMatch(_ctx(hasReading: false)), isNull);
    });

    test('it does NOT fire inside a saved place', () {
      final rules = ContextRules([_commute()]);
      expect(rules.firstMatch(_ctx(placeId: 'gym')), isNull);
      expect(rules.firstMatch(_ctx(placeId: 'uni')), isNull);
      expect(rules.firstMatch(_ctx(placeId: 'home')), isNull);
    });
  });

  group('it coexists with the named place rules', () {
    test('a place rule wins inside the place, commuting wins outside', () {
      final rules = ContextRules([
        ContextRule(id: 'gym', priority: 70, placeId: 'gym', playlist: 'Gym Metal'),
        _commute(),
      ]);

      expect(rules.firstMatch(_ctx(placeId: 'gym'))?.playlist, 'Gym Metal');
      expect(rules.firstMatch(_ctx())?.playlist, 'Commuting');
    });

    test('the named rule does NOT fire while commuting', () {
      final rules = ContextRules([
        ContextRule(id: 'gym', priority: 70, placeId: 'gym', playlist: 'Gym Metal'),
        _commute(),
      ]);
      expect(rules.firstMatch(_ctx())?.playlist, isNot('Gym Metal'));
    });

    test('with no reading, NEITHER fires — not even the named one', () {
      final rules = ContextRules([
        ContextRule(id: 'gym', priority: 70, placeId: 'gym', playlist: 'Gym Metal'),
        _commute(),
      ]);
      expect(rules.firstMatch(_ctx(hasReading: false)), isNull);
    });

    test('commuting outranks the clock, because it is more specific', () {
      final rules = ContextRules([
        ContextRule(
          id: 'afternoon',
          priority: 10,
          band: ContextBand.afternoon,
          playlist: 'Afternoon'),
        _commute(),
      ]);
      expect(rules.firstMatch(_ctx())?.playlist, 'Commuting');
    });
  });

  group('reading it back from a rules file', () {
    test('"place": "anywhere" becomes the anywhere want', () {
      final rules = ContextRules.decode('''
        {"rules":[
          {"id":"commuting","priority":66,
           "when":{"place":"anywhere"},"playlist":"Commuting"}
        ]}
      ''');
      expect(rules.length, 1);
      expect(rules.rules.first.place, PlaceWant.anywhere);
      expect(rules.rules.first.placeId, isNull);
      expect(rules.firstMatch(_ctx())?.playlist, 'Commuting');
    });

    test('a real place id is NOT mistaken for the keyword', () {
      final rules = ContextRules.decode('''
        {"rules":[
          {"id":"uni","priority":70,
           "when":{"place":"uni"},"playlist":"Campus"}
        ]}
      ''');
      expect(rules.rules.first.place, PlaceWant.any);
      expect(rules.rules.first.placeId, 'uni');
      expect(rules.firstMatch(_ctx(placeId: 'uni'))?.playlist, 'Campus');
    });

    test('the keyword is case-insensitive', () {
      final rules = ContextRules.decode('''
        {"rules":[
          {"id":"c","priority":66,
           "when":{"place":"Anywhere"},"playlist":"Commuting"}
        ]}
      ''');
      expect(rules.rules.first.place, PlaceWant.anywhere);
      expect(rules.firstMatch(_ctx())?.playlist, 'Commuting');
    });

    test('it round-trips through toJson', () {
      final encoded = ContextRules([_commute()]).encode();
      final back = ContextRules.decode(encoded);
      expect(back.rules.first.place, PlaceWant.anywhere);
      expect(back.firstMatch(_ctx())?.playlist, 'Commuting');
    });

    test('it describes itself in a way a person can read', () {
      expect(_commute().describe(), contains('none of your places'));
    });
  });
}
