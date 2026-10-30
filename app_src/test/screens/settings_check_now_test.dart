import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/update/update_service.dart';

/// The switch is about phoning home uninvited. A person pressing CHECK NOW is
/// invited, so it runs either way — and it has to say what it found, in place,
/// instead of flashing a snackbar that leaves with the frame.
void main() {
  Widget host(Future<AppUpdate?> Function() check) => MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            state: AppState(),
            prefs: AppPrefs.initial,
            onPrefsChanged: (_) {},
            appVersion: '0.2.0+20',
            checkUpdate: check,
          ),
        ),
      );

  Future<void> openSystemTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.tap(find.text('SYSTEM'));
    await tester.pumpAndSettle();
    // INTERFACE sits below the fold on a phone-sized surface.
    await tester.scrollUntilVisible(
      find.text('CHECK NOW'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the newest build says so', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(() async {
      calls++;
      return null;
    }));
    await openSystemTab(tester);

    await tester.tap(find.text('CHECK NOW'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.textContaining('newest build'), findsOneWidget);
  });

  testWidgets('a newer build is named, and the banner is pointed at',
      (tester) async {
    await tester.pumpWidget(host(() async => const AppUpdate(
          version: '0.2.2+22',
          build: 22,
          apkUrl: 'https://example.test/sonarar.apk',
          notesUrl: 'https://example.test/notes',
          sizeBytes: 1024,
        )));
    await openSystemTab(tester);

    await tester.tap(find.text('CHECK NOW'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0.2.2+22 is available'), findsOneWidget);
  });
}
