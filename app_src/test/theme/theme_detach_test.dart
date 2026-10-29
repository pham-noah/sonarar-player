import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_preset.dart';

/// A theme sets the look once. It does not get to overrule the user later.
///
/// The bug this pins: apply a theme, change the accent, restart — the theme's
/// snapshot was reapplied over the change, because the preset stayed attached.
void main() {
  AccentSpec red() =>
      AccentSpec(source: AccentSource.manual, value: 0xFFFF2D55);

  ThemePreset themeWith(AccentSpec accent) => ThemePreset(
        id: 'night',
        name: 'Night',
        skinId: SkinId.abyss,
        personalization: Personalization.defaults.copyWith(accent: accent),
      );

  test('applying a theme sets its accent', () {
    final state = AppState();
    state.applyPreset(themeWith(red()));
    expect(state.skin.accent, const Color(0xFFFF2D55));
  });

  test('changing the accent afterwards detaches the theme, so it cannot win back',
      () {
    final state = AppState();
    state.applyPreset(themeWith(red()));

    state.setPersonalization(
      state.personalization.copyWith(
        accent: const AccentSpec(source: AccentSource.manual, value: 0xFF00E5A0),
      ),
    );

    expect(state.preset, isNull,
        reason: 'the theme stayed attached, so the next launch would restore '
            'its accent over the one the user just picked');
    expect(state.skin.accent, const Color(0xFF00E5A0));
  });

  test('a change that matches the theme leaves it attached', () {
    final state = AppState();
    final theme = themeWith(red());
    state.applyPreset(theme);

    state.setPersonalization(theme.personalization!);

    expect(state.preset?.id, 'night');
  });
}
