library;

// P0-2 and P0-3 of `docs/design/2026-11-14-ui-audit.md`: Android's 48dp floor,
// once, and the stepper's value format.
//
// Four controls were under it — the two stepper keys (34×34), the tab strip
// (34) and the mini player's neighbour buttons (44) — and each one was the
// smallest thing on its screen. These assertions are the reason a later change
// cannot quietly shrink them back: a size is a decision, and this is where it
// is written down.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/tokens.dart';
import 'package:sonarar/widgets/kit.dart';

const _floor = 48.0;

/// The smallest phone the app claims to support, at 3× — the case where the
/// settings row used to cut its label to `FADE…`.
Future<void> _pump(WidgetTester tester, SettingsSection section,
    {bool showTitle = false}) async {
  tester.view.physicalSize = const Size(320, 640) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: SettingsScreen(
        state: AppState(),
        section: section,
        prefs: AppPrefs.initial,
        onPrefsChanged: (_) {},
        showTitle: showTitle,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Iterable<Size> _sizesOf(WidgetTester tester, Finder finder) =>
    tester.widgetList(finder).map((w) => tester.getSize(find.byWidget(w)));

void main() {
  test('the token says 48', () {
    expect(Space.tap, _floor);
    expect(LayoutSpec.secondaryActionHeight, _floor);
  });

  testWidgets('every stepper key is at least 48dp', (tester) async {
    await _pump(tester, SettingsSection.behaviour);

    final keys = find.ancestor(
      of: find.byIcon(Icons.add_rounded),
      matching: find.byType(InkWell),
    );
    expect(keys, findsWidgets, reason: 'no stepper on the BEHAVIOUR page');

    for (final size in _sizesOf(tester, keys)) {
      expect(size.width, greaterThanOrEqualTo(_floor));
      expect(size.height, greaterThanOrEqualTo(_floor));
    }
  });

  testWidgets('the settings tab strip is at least 48dp', (tester) async {
    await _pump(tester, SettingsSection.behaviour, showTitle: true);

    expect(tester.getSize(find.byType(KitTabs<SettingsTab>)).height,
        greaterThanOrEqualTo(_floor));
  });

  testWidgets('every stepper value carries its unit', (tester) async {
    await _pump(tester, SettingsSection.behaviour);

    // One rule: unit always, space before, no abbreviations — `5 s`,
    // `30 min` — where the app used to mix `OFF`, `30 min` and `30m`.
    final values = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => RegExp(r'^\d+ ?[a-z]*$').hasMatch(s))
        .toList();

    expect(values, isNotEmpty, reason: 'no numeric stepper value on screen');
    for (final v in values) {
      expect(RegExp(r'^\d+ (s|min)$').hasMatch(v), isTrue,
          reason: '"$v" is not the agreed value format');
    }
  });
}
