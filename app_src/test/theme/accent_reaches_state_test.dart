import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/layout_kit.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';

/// The accent has to reach the screens that resolve through a
/// `PresentationScope` — Search, the drawer — not just Home.
///
/// That path calls `asSkin` a second time, and before the pin it replaced the
/// user's accent with the layout palette's. This test walks the real state:
/// pick an accent, then ask each layer what colour it would paint.
void main() {
  const chosen = Color(0xFFFF2D55);

  AppState withAccent() {
    final state = AppState();
    state.setPersonalization(
      state.personalization.copyWith(
        accent: AccentSpec(source: AccentSource.manual, value: chosen.toARGB32()),
      ),
    );
    return state;
  }

  test('a picked accent reaches state.skin', () {
    expect(withAccent().skin.accent, chosen);
  });

  test('it survives the presentation the drawer and Search resolve through', () {
    final state = withAccent();
    final presentation = Presentation(
      layout: state.layoutId,
      palette: state.presentation.palette,
      material: MaterialStyle.flat,
      motion: MotionSpec.persona,
      arrangement: ScreenLayout.persona,
      kit: kGlassKit,
    );
    final resolved = presentation.asSkin(state.skin);
    expect(resolved.accent, chosen,
        reason: 'asSkin recoloured the accent from the palette — Search, the '
            'drawer and back arrows would disagree with Home');
  });

  test('it reaches the app theme, which is what colours ripples and icons', () {
    final state = withAccent();
    final theme = themeFor(state.skin, layout: state.presentation);
    expect(theme.colorScheme.primary, chosen);
  });
}
