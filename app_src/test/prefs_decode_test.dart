library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs_decode.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

void main() {
  group('layoutFromPrefs', () {
    test('a known name is that layout', () {
      expect(layoutFromPrefs('solid'), LayoutKind.solid);
      expect(layoutFromPrefs('glass'), LayoutKind.glass);
    });

    test('an unknown or junk name is PERSONA, never a throw', () {
      for (final junk in ['', 'PERSONA', 'ultra', '  solid', 'solid\n', '{"layout":"glass"}']) {
        expect(layoutFromPrefs(junk), LayoutKind.persona,
            reason: 'the name "$junk" should degrade to Persona');
      }
    });
  });

  group('skinFromPrefs', () {
    test('a real skin id round-trips through its name', () {
      for (final s in kAllSkins) {
        expect(skinFromPrefs(s.id.name), s.id,
            reason: '${s.id.name} should resolve back to itself');
      }
    });

    test('NULL IN MEANS NULL OUT — "no opinion", not "no skin"', () {
      expect(skinFromPrefs(null), isNull);
    });

    test('an unknown name is null, never a throw', () {
      for (final junk in ['', 'aurora', 'P5R', 'p5r ', '{}']) {
        expect(skinFromPrefs(junk), isNull,
            reason: 'the name "$junk" has no skin and must resolve to null');
      }
    });
  });

  group('bandNameOf', () {
    test('every band has a word', () {
      final named = <ContextBand, String>{
        ContextBand.darkHour: 'NIGHT HOUR',
        ContextBand.morning: 'MORNING',
        ContextBand.afternoon: 'AFTERNOON',
        ContextBand.evening: 'EVENING',
        ContextBand.night: 'NIGHT',
      };
      named.forEach((band, word) {
        expect(bandNameOf(band), word);
      });

      expect(named.keys.toSet(), ContextBand.values.toSet(),
          reason: 'a band was added to ContextBand without a word in this decode layer');
    });

    test('no band is null, not the string "null"', () {
      expect(bandNameOf(null), isNull);
    });
  });
}
