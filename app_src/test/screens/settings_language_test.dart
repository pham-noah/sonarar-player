import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';

/// The language row: it exists, it lists every language the build can speak,
/// and picking one is saved rather than just announced.
void main() {
  Widget host(List<AppPrefs> saved, {String? locale}) => MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            state: AppState(),
            prefs: AppPrefs.initial.copyWith(locale: locale),
            onPrefsChanged: saved.add,
          ),
        ),
      );

  Future<void> openSystemTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.tap(find.text('SYSTEM'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('LANGUAGE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('following the phone is the default and says so',
      (tester) async {
    await tester.pumpWidget(host([]));
    await openSystemTab(tester);

    expect(find.text('LANGUAGE'), findsOneWidget);
    expect(find.text('SYSTEM'), findsWidgets);
  });

  testWidgets('a stored language is shown in its own words', (tester) async {
    await tester.pumpWidget(host([], locale: 'ja'));
    await openSystemTab(tester);

    expect(find.text('日本語'), findsOneWidget,
        reason: 'a Japanese speaker looks for 日本語, not for "JAPANESE"');
  });

  testWidgets('picking a language saves it', (tester) async {
    final saved = <AppPrefs>[];
    await tester.pumpWidget(host(saved));
    await openSystemTab(tester);

    await tester.tap(find.text('LANGUAGE'));
    await tester.pumpAndSettle();
    expect(find.text('TIẾNG VIỆT'), findsOneWidget);
    // Offered only if the build speaks it: a language with no ARB would answer
    // in English and look finished.
    expect(find.text('简体中文'), findsNothing,
        reason: 'zh-Hans has no ARB yet, so it must not be offered');

    await tester.tap(find.text('TIẾNG VIỆT'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.locale, 'vi');
  });

  testWidgets('choosing the system clears the stored tag', (tester) async {
    final saved = <AppPrefs>[];
    await tester.pumpWidget(host(saved, locale: 'fi'));
    await openSystemTab(tester);

    await tester.tap(find.text('LANGUAGE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SYSTEM').last);
    await tester.pumpAndSettle();

    // copyWith cannot express "clear", so the saved value must be built by
    // something that can. If this ever regresses, the app is stuck in Finnish.
    expect(saved, hasLength(1));
    expect(saved.single.locale, isNull);
  });
}
