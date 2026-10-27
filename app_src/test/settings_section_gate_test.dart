library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';

Future<void> _pump(WidgetTester tester, SettingsSection section) async {
  tester.view.physicalSize = const Size(400, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: SettingsScreen(
        state: AppState(),
        section: section,
        prefs: AppPrefs.initial,
        onPrefsChanged: (_) {},
        showTitle: false,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('BEHAVIOUR shows no LAYOUT / SONG LIST / THEME / ART controls', (tester) async {
    await _pump(tester, SettingsSection.behaviour);

    expect(find.text('LAYOUT'), findsNothing);
    expect(find.text('SONG LIST'), findsNothing);
    expect(find.text('THEME'), findsNothing);
    expect(find.text('ART'), findsNothing);

    expect(find.text('GRID'), findsNothing,
        reason: 'the SONG LIST grid/list tiles are still drawn on the BEHAVIOUR section — a gate that hides '
            'the heading but not the thing it labels');
    expect(find.text('LIST'), findsNothing);
    expect(find.text('PERSONA'), findsNothing,
        reason: 'the LAYOUT tiles are still drawn on the BEHAVIOUR section');
    expect(find.text('SOLID'), findsNothing);
    expect(find.text('GLASS'), findsNothing);
  });

  testWidgets('and CUSTOMIZATION still shows them', (tester) async {
    await _pump(tester, SettingsSection.customization);
    expect(find.text('SOLID'), findsOneWidget,
        reason: 'the LAYOUT tiles vanished from the CUSTOMIZATION section too — the gate is now too wide');
  });
}
