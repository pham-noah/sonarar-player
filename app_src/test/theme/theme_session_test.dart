import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_preset.dart';
import 'package:sonarar/theme/theme_session.dart';

/// Editing a theme is live — an accent drag fires dozens of changes. The file
/// gets one write when the hand stops, not one per frame.
void main() {
  ThemePreset theme(String id) => ThemePreset(
        id: id,
        name: id,
        skinId: SkinId.abyss,
      );

  test('a burst of edits writes once, with the last state', () async {
    final writes = <List<ThemePreset>>[];
    final session = ThemeSession(
      save: (presets) async => writes.add(presets),
      settle: const Duration(milliseconds: 20),
    );

    session.touched([theme('a')]);
    session.touched([theme('b')]);
    session.touched([theme('c')]);
    expect(writes, isEmpty, reason: 'nothing is written while the hand moves');

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(writes.length, 1);
    expect(writes.single.single.id, 'c');
  });

  test('leaving the screen flushes what is still pending', () async {
    final writes = <List<ThemePreset>>[];
    final session = ThemeSession(
      save: (presets) async => writes.add(presets),
      settle: const Duration(seconds: 30),
    );

    session.touched([theme('a')]);
    await session.flush();

    expect(writes.single.single.id, 'a');
  });

  test('nothing pending means nothing written', () async {
    final writes = <List<ThemePreset>>[];
    final session = ThemeSession(save: (p) async => writes.add(p));
    await session.flush();
    expect(writes, isEmpty);
  });
}
