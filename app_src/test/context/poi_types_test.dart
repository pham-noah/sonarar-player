library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/context/poi_types.dart';

void main() {
  group('a kind is matched by its own tags', () {
    test('the obvious ones', () {
      expect(poiKindFor({'leisure': 'fitness_centre'})?.id, 'gym');
      expect(poiKindFor({'amenity': 'library'})?.id, 'library');
      expect(poiKindFor({'amenity': 'university'})?.id, 'university');
      expect(poiKindFor({'amenity': 'restaurant'})?.id, 'restaurant');
      expect(poiKindFor({'amenity': 'cafe'})?.id, 'cafe_study');
      expect(poiKindFor({'railway': 'station'})?.id, 'transit');
      expect(poiKindFor({'amenity': 'place_of_worship'})?.id, 'place_of_worship');
      expect(poiKindFor({'leisure': 'park'})?.id, 'park');
    });

    test('a real Overpass payload classifies', () {
      expect(poiKindFor({'amenity': 'fuel'})?.id, 'parking');
      expect(poiKindFor({'amenity': 'atm'})?.id, isNull,
          reason: 'an ATM is not a place you sit — no kind is the right answer');
      expect(poiKindFor({'amenity': 'fast_food'})?.id, 'restaurant');
    });
  });

  group('the more specific kind wins, which is why order is load-bearing', () {
    test('a gym inside a hotel is a gym', () {
      final tags = {'leisure': 'fitness_centre', 'tourism': 'hotel'};
      expect(poiKindFor(tags)?.id, 'gym');
    });

    test('a restaurant inside a mall is a restaurant', () {
      final tags = {'amenity': 'restaurant', 'shop': 'mall'};
      expect(poiKindFor(tags)?.id, 'restaurant');
    });

    test('a university library is a library', () {
      final tags = {'amenity': 'library', 'building': 'university'};
      expect(poiKindFor(tags)?.id, 'library');
    });
  });

  group('no kind is a real answer, not a failure', () {
    test('empty tags match nothing', () {
      expect(poiKindFor(const {}), isNull);
    });

    test('an unrelated tag matches nothing', () {
      expect(poiKindFor({'building': 'yes'}), isNull);
      expect(poiKindFor({'highway': 'residential'}), isNull);
      expect(poiKindFor({'natural': 'tree'}), isNull);
    });

    test('a NAME is never used to guess', () {
      expect(poiKindFor({'name': 'The Library'}), isNull);
      expect(poiKindFor({'name': 'Gym'}), isNull);
      expect(poiKindFor({'name': 'Central Park'}), isNull);
    });

    test('a near-miss value does not match', () {
      expect(poiKindFor({'leisure': 'fitness'}), isNull);
      expect(poiKindFor({'amenity': 'libraries'}), isNull);
      expect(poiKindFor({'leisure': 'swimming_pool'})?.id, 'swimming');
    });
  });

  group('the suggestion is a starting point, not a rule', () {
    test('every kind suggests something non-empty', () {
      for (final k in kPoiKinds) {
        expect(k.suggestedPlaylist.trim(), isNotEmpty, reason: k.id);
        expect(k.label.trim(), isNotEmpty, reason: k.id);
        expect(k.osmTags, isNotEmpty, reason: '${k.id} can never match');
      }
    });

    test('ids are unique', () {
      final ids = kPoiKinds.map((k) => k.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every mood is reachable, so none is dead vocabulary', () {
      final used = kPoiKinds.map((k) => k.mood).toSet();
      for (final m in PoiMood.values) {
        if (m == PoiMood.any) continue;
        expect(used, contains(m), reason: 'no kind uses $m');
      }
    });

    test('every osm tag is a well-formed key=value', () {
      for (final k in kPoiKinds) {
        for (final t in k.osmTags) {
          expect(t.contains('='), isTrue, reason: '${k.id}: "$t" has no =');
          expect(t.indexOf('='), greaterThan(0), reason: '${k.id}: "$t"');
          expect(t.endsWith('='), isFalse, reason: '${k.id}: "$t" has no value');
        }
      }
    });
  });

  group('the quiet places are quiet', () {
    test('somewhere you should be silent does not suggest energetic music', () {
      for (final id in ['place_of_worship', 'hospital', 'cinema']) {
        final kind = kPoiKinds.firstWhere((k) => k.id == id);
        expect(kind.mood, PoiMood.quiet, reason: id);
      }
    });
  });
}
