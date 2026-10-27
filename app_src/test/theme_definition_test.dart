library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/layout_kit.dart';
import 'package:sonarar/theme/theme_store.dart' show kBuiltInThemeFiles;
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_definition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, ThemeDefinition>> bundled() async {
    final out = <String, ThemeDefinition>{};
    for (final name in kBuiltInThemeFiles) {
      final raw = await rootBundle.loadString('assets/themes/$name');
      final result = ThemeDefinition.decode(jsonDecode(raw), sourceName: name);
      result.when(
        valid: (t) => out[t.id] = t,
        invalid: (issues) => fail('$name failed to decode: $issues'),
      );
    }
    return out;
  }

  group('the shipped theme files decode', () {
    test('all nine load, with the ids the registry expects', () async {
      final themes = await bundled();
      expect(themes.keys.toSet(), kBuiltInThemeFiles.map(_idOf).toSet());
    });

    test('they are all built-in, and the ids match their filenames', () async {
      final themes = await bundled();
      for (final name in kBuiltInThemeFiles) {
        final theme = themes[_idOf(name)]!;
        expect(theme.builtIn, isTrue,
            reason: '$name ships with the app, so it is a built-in');
        expect(_idOf(name), theme.id);
      }
    });
  });

  group('a decoded theme is THE SAME THEME the app used to build', () {
    for (final skin in kAllSkins) {
      test('persona_${skin.id.name} round-trips exactly', () async {
        final themes = await bundled();
        final theme = themes['persona_${skin.id.name}']!;
        final kit = LayoutKind.persona.kit;

        expect(theme.palette.accent, skin.accent);
        expect(theme.palette.accentDeep, skin.accentDeep);
        expect(theme.palette.background, skin.background);
        expect(theme.palette.surface, skin.panel);
        expect(theme.palette.onAccent, skin.onAccent);
        expect(theme.material, kit.material);
        expect(theme.motion.tabTransition, kit.motion.tabTransition);
        expect(theme.arrangement, kit.arrangement);
        expect(theme.chrome, kit.chrome);
      });
    }

    test('solid_forest round-trips exactly', () async {
      final themes = await bundled();
      final theme = themes['solid_forest']!;
      final kit = LayoutKind.solid.kit;

      expect(theme.material, kit.material);
      expect(theme.motion.tabTransition, kit.motion.tabTransition);
      expect(theme.arrangement, kit.arrangement);
      expect(theme.chrome, kit.chrome);
      expect(theme.palette.accent, kit.palettes.first.palette.accent);
    });

    test('glass_aurora round-trips exactly', () async {
      final themes = await bundled();
      final theme = themes['glass_aurora']!;
      final kit = LayoutKind.glass.kit;

      expect(theme.material.blur, greaterThan(0),
          reason: 'glass blurs; a decoded file that does not has lost the material');
      expect(theme.chrome, kit.chrome);
    });
  });

  group('a theme file is a diffable document', () {
    test('toJson -> decode is the identity', () async {
      final themes = await bundled();
      for (final theme in themes.values) {
        final again = ThemeDefinition.decode(
          jsonDecode(jsonEncode(theme.toJson())),
          sourceName: theme.id,
        );
        again.when(
          valid: (t) {
            expect(t.id, theme.id);
            expect(t.palette, theme.palette);
            expect(t.material, theme.material);
            expect(t.motion.tabTransition, theme.motion.tabTransition);
            expect(t.arrangement, theme.arrangement);
            expect(t.chrome, theme.chrome);
          },
          invalid: (issues) => fail('${theme.id} did not survive a round trip'),
        );
      }
    });
  });

  group('validation catches what a hand-edited file gets wrong', () {
    Map<String, Object?> goodFile() => {
          'id': 'mine',
          'displayName': 'Mine',
          'palette': {
            'background': '#0a0a0c',
            'surface': '#1c1c22',
            'textPrimary': '#ffffff',
            'textSecondary': '#e8e8ee',
            'accent': '#e60012',
            'accentDeep': '#a3000d',
            'onAccent': '#ffffff',
            'border': '#606060',
            'shadow': '#000000',
          },
        };

    test('a well-formed minimal file decodes', () {
      ThemeDefinition.decode(goodFile(), sourceName: 'mine.json').when(
            valid: (_) => null,
            invalid: (i) => fail('a valid file was rejected: $i'),
          );
    });

    test('a colour that is not a colour is rejected, naming the field', () {
      final f = goodFile();
      (f['palette'] as Map<String, Object?>)['accent'] = '#zzz';
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (_) => fail('a non-colour was accepted'),
        invalid: (issues) {
          expect(issues.any((i) => i.field == 'palette.accent'), isTrue);
        },
      );
    });

    test('an unreadable text colour IS a rejection', () {
      final f = goodFile();
      (f['palette'] as Map<String, Object?>)['textPrimary'] = '#0a0a0c';
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (_) => fail('unreadable text was accepted'),
        invalid: (issues) {
          expect(issues.map((i) => i.field).contains('palette.textPrimary'),
              isTrue,
              reason: 'the file has to say WHICH colour is too dark');
        },
      );
    });

    test('a low-contrast ACCENT is a warning, not a rejection', () {
      final f = goodFile();
      final pal = f['palette'] as Map<String, Object?>;
      pal['accent'] = '#9a9a9a';
      pal['onAccent'] = '#000000';
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (_) => null,
        invalid: (i) => fail('a low-contrast accent should warn, not reject: $i'),
      );
    });

    test('a missing id is rejected, and says so', () {
      final f = goodFile()..remove('id');
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (_) => fail('a theme with no id was accepted'),
        invalid: (issues) {
          expect(issues.any((i) => i.field == 'id'), isTrue);
        },
      );
    });

    test('a newer schema version is skipped rather than read with defaults', () {
      final f = goodFile()..['schema'] = 99;
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (_) => fail('a newer schema was read anyway'),
        invalid: (issues) {
          expect(issues.single.field, 'schema');
        },
      );
    });

    test('an unknown enum name degrades to the documented default', () {
      final f = goodFile()..['chrome'] = {'sectionBand': 'nonsense'};
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (t) {
          expect(t.chrome.sectionBand, SectionBandForm.banner,
              reason: 'an unknown form falls back to the banner');
        },
        invalid: (i) => fail('an unknown enum name should degrade, not reject'),
      );
    });

    test('a whole missing section means "use the default"', () {
      final f = goodFile()..remove('chrome');
      ThemeDefinition.decode(f, sourceName: 'mine.json').when(
        valid: (t) => expect(t.chrome, ChromeKit.persona),
        invalid: (i) => fail('a file with no chrome section was rejected: $i'),
      );
    });

    test('a root that is not an object is rejected without throwing', () {
      ThemeDefinition.decode([1, 2, 3], sourceName: 'mine.json').when(
        valid: (_) => fail('an array was accepted'),
        invalid: (issues) => expect(issues.single.field, '(root)'),
      );
    });
  });
}

String _idOf(String filename) => filename.substring(0, filename.length - 5);
