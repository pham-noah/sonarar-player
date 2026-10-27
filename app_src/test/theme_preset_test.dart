library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_preset.dart';

void main() {
  group('the parts come apart', () {
    test('a preset with no art or language FOLLOWS its palette', () {
      const p = ThemePreset(id: 'x', name: 'X', skinId: SkinId.crimson);
      expect(p.effectiveArtSkin, SkinId.crimson);
      expect(p.effectiveLanguageSkin, SkinId.crimson);
    });

    test('art can be borrowed from another skin', () {
      const p = ThemePreset(
        id: 'x',
        name: 'Red with Makoto',
        skinId: SkinId.crimson,
        artSkinId: SkinId.abyss,
      );
      expect(p.effectiveArtSkin, SkinId.abyss);
      expect(p.effectiveLanguageSkin, SkinId.crimson, reason: 'language untouched');
    });

    test('language can be borrowed independently of both', () {
      const p = ThemePreset(
        id: 'x',
        name: 'Plain words',
        skinId: SkinId.crimson,
        artSkinId: SkinId.abyss,
        languageSkinId: SkinId.minimal,
      );
      expect(p.effectiveArtSkin, SkinId.abyss);
      expect(p.effectiveLanguageSkin, SkinId.minimal);
    });
  });

  group('editing a preset', () {
    test('an edited preset is never still a built-in', () {
      final built = ThemePreset(
        id: 'builtin_p5r',
        name: 'Phantom',
        skinId: SkinId.crimson,
        builtIn: true,
      );
      final mine = built.copyWith(id: 'tp_1', name: 'My Red');
      expect(mine.builtIn, isFalse,
          reason: 'a copy of a built-in is the user\'s, so it can be deleted');
    });

    test('copyWith can UNBIND art, going back to following the palette', () {
      const p = ThemePreset(
          id: 'x', name: 'X', skinId: SkinId.crimson, artSkinId: SkinId.abyss);
      expect(p.copyWith(clearArt: true).effectiveArtSkin, SkinId.crimson);
    });

    test('copyWith can UNBIND language the same way', () {
      const p = ThemePreset(
          id: 'x', name: 'X', skinId: SkinId.crimson, languageSkinId: SkinId.minimal);
      expect(p.copyWith(clearLanguage: true).effectiveLanguageSkin, SkinId.crimson);
    });

    test('copyWith leaves what it was not given', () {
      const p = ThemePreset(
          id: 'x', name: 'X', skinId: SkinId.crimson, artSkinId: SkinId.abyss);
      final renamed = p.copyWith(name: 'Renamed');
      expect(renamed.skinId, SkinId.crimson);
      expect(renamed.artSkinId, SkinId.abyss);
    });
  });

  group('persistence', () {
    test('a preset survives a round trip, all four parts', () {
      const p = ThemePreset(
        id: 'tp_1',
        name: 'Mine',
        skinId: SkinId.minimal,
        artSkinId: SkinId.crimson,
        languageSkinId: SkinId.bloom,
      );
      final back = ThemePreset.fromJson(p.toJson())!;
      expect(back.id, 'tp_1');
      expect(back.name, 'Mine');
      expect(back.skinId, SkinId.minimal);
      expect(back.artSkinId, SkinId.crimson);
      expect(back.languageSkinId, SkinId.bloom);
    });

    test('an unset part stays unset rather than being written as null', () {
      const p = ThemePreset(id: 'x', name: 'X', skinId: SkinId.crimson);
      final json = p.toJson();
      expect(json.containsKey('art'), isFalse);
      expect(ThemePreset.fromJson(json)!.artSkinId, isNull);
    });

    test('a preset naming a skin this build does not have is DROPPED', () {
      expect(
        ThemePreset.fromJson({'id': 'x', 'name': 'X', 'skin': 'laserwave'}),
        isNull,
      );
    });

    test('an unknown ART falls back to the palette instead of losing the preset', () {
      final p = ThemePreset.fromJson(
        {'id': 'x', 'name': 'X', 'skin': 'p5r', 'art': 'laserwave'},
      );
      expect(p, isNotNull);
      expect(p!.skinId, SkinId.crimson);
      expect(p.artSkinId, isNull);
      expect(p.effectiveArtSkin, SkinId.crimson);
    });

    test('a record with no id or name is dropped', () {
      expect(ThemePreset.fromJson({'name': 'No id'}), isNull);
      expect(ThemePreset.fromJson({'id': 'x'}), isNull);
    });
  });

  group('the store', () {
    test('round-trips through a real file', () async {
      final dir = Directory.systemTemp.createTempSync('presets');
      final file = File('${dir.path}/theme_presets.json');
      try {
        final store = ThemePresetStore(file);
        expect(await store.load(), isEmpty, reason: 'missing file is empty, not an error');

        await store.save(const [
          ThemePreset(id: 'tp_1', name: 'One', skinId: SkinId.bloom),
          ThemePreset(
              id: 'tp_2',
              name: 'Two',
              skinId: SkinId.mono,
              artSkinId: SkinId.amber),
        ]);
        final back = await store.load();
        expect(back.map((p) => p.name), ['One', 'Two']);
        expect(back[1].artSkinId, SkinId.amber);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('a truncated file loses the presets rather than the launch', () {
      expect(ThemePresetStore.decode('{"presets": [{"id":'), isEmpty);
      expect(ThemePresetStore.decode('not json at all'), isEmpty);
    });

    test('a duplicate id is accepted once, so delete cannot remove two rows', () {
      final decoded = ThemePresetStore.decode(
        '{"presets":[{"id":"a","name":"A","skin":"p5r"},'
        '{"id":"a","name":"A again","skin":"p3r"}]}',
      );
      expect(decoded, hasLength(1));
      expect(decoded.first.skinId, SkinId.crimson);
    });
  });

  group('the chosen preset is remembered', () {
    test('a preset id survives a prefs round trip', () {
      const prefs = AppPrefs();
      final withPreset = prefs.copyWith(activePresetId: 'tp_1');
      expect(withPreset.activePresetId, 'tp_1');
      expect(AppPrefs.fromJson(withPreset.toJson()).activePresetId, 'tp_1');
    });

    test('clearing it goes back to the context, and STAYS cleared', () {
      final pinned = const AppPrefs().copyWith(activePresetId: 'tp_1');
      final cleared = pinned.copyWith(clearPreset: true);
      expect(cleared.activePresetId, isNull);
      expect(cleared.toJson().containsKey('active_preset'), isFalse);
      expect(AppPrefs.fromJson(cleared.toJson()).activePresetId, isNull);
    });

    test('an app with no preset writes no key', () {
      expect(const AppPrefs().toJson().containsKey('active_preset'), isFalse);
      expect(const AppPrefs().activePresetId, isNull);
    });

    test('a preset id is not invented from an empty string', () {
      expect(
        AppPrefs.fromJson({'active_preset': '   '}).activePresetId,
        isNull,
      );
    });
  });

  group('the built-ins', () {
    test('every shipped skin has a built-in preset', () {
      expect(kBuiltInPresets.map((p) => p.skinId).toSet(),
          {for (final s in kAllSkins) s.id});
    });

    test('they are marked built-in, so they cannot be deleted', () {
      expect(kBuiltInPresets.every((p) => p.builtIn), isTrue);
    });

    test('they follow their own palette for art and language', () {
      for (final p in kBuiltInPresets) {
        expect(p.effectiveArtSkin, p.skinId, reason: p.name);
        expect(p.effectiveLanguageSkin, p.skinId, reason: p.name);
      }
    });

    test('a generated id never collides with a built-in one', () {
      final taken = {for (final p in kBuiltInPresets) p.id};
      final fresh = freshPresetId(taken);
      expect(taken.contains(fresh), isFalse);
      expect(fresh.startsWith('tp_'), isTrue);
    });
  });
}
