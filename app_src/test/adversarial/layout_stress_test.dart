// Layout stress QA: the densest screens on a small phone with the system font
// size turned up, which is an accessibility setting real users run every day.
@Tags(['adversarial'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/screens/first_run_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  const sizes = <String, Size>{
    'small 320dp': Size(320, 640),
    'common 360dp': Size(360, 740),
    'large 412dp': Size(412, 915),
  };
  const scales = <double>[1.0, 1.3, 1.6, 2.0];

  void sizeAndScale(WidgetTester tester, Size size, double scale) {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  for (final size in sizes.entries) {
    for (final scale in scales) {
      testWidgets('first run fits at ${size.key} / ${scale}x text',
          (tester) async {
        sizeAndScale(tester, size.value, scale);

        await tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FirstRunScreen(
            skin: kSkinAbyss,
            prefs: AppPrefs.initial,
            layoutId: LayoutKind.sonar,
            onPrefs: (_) {},
            onDone: () {},
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'first run overflowed at ${size.key} / ${scale}x');
      });

      for (final locale in AppLocalizations.supportedLocales) {
        testWidgets(
            'settings fits at ${size.key} / ${scale}x text / ${locale.languageCode}',
            (tester) async {
          sizeAndScale(tester, size.value, scale);

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
              reason: 'settings overflowed at ${size.key} / ${scale}x / '
                  '${locale.languageCode}');
        });
      }
    }
  }
}
