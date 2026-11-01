import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/screens/settings_screen.dart';

/// English goldens cannot catch a Finnish compound or a Vietnamese sentence
/// overrunning a row. This pumps the densest screen in every language the build
/// speaks and fails on any layout exception it draws.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    final tag = locale.toLanguageTag();

    testWidgets('the settings page fits in $tag', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettingsScreen(
            state: AppState(),
            prefs: AppPrefs.initial,
            onPrefsChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'the settings page drew an overflow in $tag');
    });
  }
}
