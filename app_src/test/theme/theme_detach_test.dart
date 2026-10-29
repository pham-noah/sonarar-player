import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_preset.dart';

/// A theme is the whole look, and editing it edits it.
///
/// The bug this pins now runs the other way: change the accent while a theme is
/// on and the change has to belong to that theme, so switching away and back
/// returns your version rather than the shipped one.
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

  test('changing the accent edits the theme instead of detaching it', () {
    final state = AppState();
    state.applyPreset(themeWith(red()));

    state.setPersonalization(
      state.personalization.copyWith(
        accent: const AccentSpec(source: AccentSource.manual, value: 0xFF00E5A0),
      ),
    );

    expect(state.preset, isNotNull,
        reason: 'the edit belongs to the theme you are wearing');
    expect(state.skin.accent, const Color(0xFF00E5A0));
  });

  test('a change that matches the theme leaves it attached', () {
    final state = AppState();
    final theme = themeWith(red());
    state.applyPreset(theme);

    state.setPersonalization(theme.personalization!);

    expect(state.preset?.id, 'night');
  });

  test('editing a theme, leaving it and coming back keeps the edit', () {
    final state = AppState();
    state.applyPreset(themeWith(red()));
    state.setPersonalization(
      state.personalization.copyWith(
        accent: const AccentSpec(source: AccentSource.manual, value: 0xFF00E5A0),
      ),
    );

    final other = ThemePreset(
      id: 'day',
      name: 'Day',
      skinId: SkinId.crimson,
      personalization: Personalization.defaults,
    );
    state.applyPreset(other);
    // The row the THEMES tab shows, which is the edited definition.
    state.applyPreset(state.allPresets.firstWhere((p) => p.id == 'night'));

    expect(state.skin.accent, const Color(0xFF00E5A0),
        reason: 'the theme you edited is the one that comes back');

    final back = state.allPresets.firstWhere((p) => p.id == 'night');
    expect(
      back.personalization!.accent.value,
      0xFF00E5A0,
      reason: 'one row per theme: the edit replaced the shipped definition',
    );
  });
}
