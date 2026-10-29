import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/prefs_decode.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/theme_preset.dart';

/// The layout was called PERSONA before it was called SONAR.
///
/// Every install and every saved theme written before the rename carries
/// `persona`, so the rename is only safe if the old string still resolves.
void main() {
  test('the old prefs value still resolves', () {
    expect(layoutFromPrefs('persona'), LayoutKind.sonar);
  });

  test('the new value resolves', () {
    expect(layoutFromPrefs('sonar'), LayoutKind.sonar);
  });

  test('the other layouts are untouched', () {
    expect(layoutFromPrefs('glass'), LayoutKind.glass);
    expect(layoutFromPrefs('solid'), LayoutKind.solid);
  });

  test('a preset saved as persona keeps its layout', () {
    final json = {
      'id': 'legacy',
      'name': 'Legacy look',
      'skin': 'abyss',
      'layout': 'persona',
    };
    final preset = ThemePreset.fromJson(json);
    expect(preset, isNotNull);
    expect(preset!.layoutId, 'persona');
  });
}
