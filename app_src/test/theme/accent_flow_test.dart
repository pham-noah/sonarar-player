import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/layout_kit.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';

/// A chosen accent has to survive the presentation layer.
///
/// `Presentation.asSkin` recolours a skin from the layout's palette, and that
/// run happens a second time wherever a screen resolves through
/// `PresentationScope` — Search, the drawer. Before the pin, the second run
/// threw the user's accent away, so Home followed the choice and those screens
/// did not.
void main() {
  const chosen = Color(0xFFFF2D55);

  Presentation glassish() => Presentation(
        layout: LayoutKind.glass,
        palette: LayoutPalette.fromSkin(kSkinAbyss),
        material: MaterialStyle.flat,
        motion: MotionSpec.persona,
        arrangement: ScreenLayout.persona,
        kit: kGlassKit,
      );

  test('a pinned accent survives asSkin', () {
    final personal = kSkinAbyss.withAccent(chosen);
    expect(personal.accentPinned, isTrue);

    final resolved = glassish().asSkin(personal);
    expect(resolved.accent, chosen);
    expect(resolved.accentDeep, accentDeepFor(chosen));
    expect(resolved.onAccent, onAccentFor(chosen));
  });

  test('an unpinned skin still takes the palette accent', () {
    final palette = glassish().palette;
    final resolved = glassish().asSkin(kSkinAbyss);
    expect(resolved.accent, palette.accent);
    expect(resolved.accentPinned, isFalse);
  });

  test('the theme carries the pinned accent into ColorScheme', () {
    final personal = kSkinAbyss.withAccent(chosen);
    final theme = themeFor(personal, layout: glassish());
    expect(theme.colorScheme.primary, chosen);
    expect(theme.colorScheme.secondary, accentDeepFor(chosen));
  });

  test('without a pin the theme keeps the palette accent', () {
    final theme = themeFor(kSkinAbyss, layout: glassish());
    expect(theme.colorScheme.primary, glassish().palette.accent);
  });
}
