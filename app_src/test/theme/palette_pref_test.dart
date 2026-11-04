library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

/// The palette has to survive the file, or the layout is applied again on the next
/// preference change and the colour snaps back to the first one.
void main() {
  group('the chosen palette', () {
    test('is the first one on an install that never picked', () {
      expect(AppPrefs.initial.paletteIndex, 0);
    });

    test('survives a round trip through the prefs file', () {
      final saved = AppPrefs.initial.copyWith(layoutId: 'glass', paletteIndex: 2);

      final back = AppPrefs.fromJson(saved.toJson());

      expect(back.layoutId, 'glass');
      expect(back.paletteIndex, 2);
    });

    test('an old file with no palette key reads as the first one, not as null', () {
      final back = AppPrefs.fromJson(const {'layout_id': 'solid', 'crossfade': 4});

      expect(back.paletteIndex, 0);
      expect(back.layoutId, 'solid');
    });

    test('a nonsense value in the file is ignored rather than crashing', () {
      final back = AppPrefs.fromJson(const {'palette': 'purple'});

      expect(back.paletteIndex, 0, reason: 'a hand-edited file must not break launch');
    });

    test('copyWith leaves it alone when it is not mentioned', () {
      final picked = AppPrefs.initial.copyWith(paletteIndex: 3);
      final edited = picked.copyWith(crossfadeSeconds: 6);

      expect(edited.paletteIndex, 3);
    });

    test('an index past the end of a layout list wraps instead of throwing', () {
      // Picking the sixth colour on Persona and then switching to a layout with
      // three palettes must not blow up.
      final p = presentationFor(
        LayoutKind.glass,
        skinFor(SkinId.crimson),
        paletteIndex: 6,
      );

      expect(p.palette.accent, isNotNull);
    });

    test('two different indices really are two different palettes', () {
      final first = presentationFor(LayoutKind.glass, skinFor(SkinId.crimson));
      final third =
          presentationFor(LayoutKind.glass, skinFor(SkinId.crimson), paletteIndex: 2);

      expect(third.palette.accent, isNot(first.palette.accent),
          reason: 'if these were equal the picker would be decoration');
    });
  });
}
