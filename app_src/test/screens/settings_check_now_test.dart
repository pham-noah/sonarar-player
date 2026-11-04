import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/update/update_service.dart';
import 'package:sonarar/update/update_ui.dart';

/// The switch is about phoning home uninvited. A person pressing CHECK FOR UPDATES
/// NOW is invited, so it runs either way — and it has to say what it found.
///
/// Two shapes are tested: the shell's real one (the row opens the update sheet,
/// which owns the offer) and the bare one (no flow supplied, so the screen writes
/// a sentence itself, which is what keeps the widget testable on its own).
void main() {
  Widget host(Future<AppUpdate?> Function() check, {UpdateUi? ui}) => MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            state: AppState(),
            prefs: AppPrefs.initial,
            onPrefsChanged: (_) {},
            appVersion: '0.2.0+20',
            checkUpdate: check,
            updateUi: ui,
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
      find.text('CHECK FOR UPDATES NOW'),
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

    await tester.tap(find.text('CHECK FOR UPDATES NOW'));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.textContaining('newest build'), findsOneWidget);
  });

  testWidgets('a newer build is named in place', (tester) async {
    await tester.pumpWidget(host(() async => const AppUpdate(
          version: '0.2.2+22',
          build: 22,
          apkUrl: 'https://example.test/sonarar.apk',
          notesUrl: 'https://example.test/notes',
          sizeBytes: 1024,
        )));
    await openSystemTab(tester);

    await tester.tap(find.text('CHECK FOR UPDATES NOW'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0.2.2+22 is available'), findsOneWidget);
  });

  testWidgets('with the update flow, the row opens the sheet and checks once',
      (tester) async {
    var checks = 0;
    final ui = UpdateUi(
      check: () async {
        checks++;
        return const AppUpdate(
          version: '0.2.2+22',
          build: 22,
          apkUrl: 'https://example.test/sonarar.apk',
          notesUrl: 'https://example.test/notes',
          sizeBytes: 65 * 1024 * 1024,
        );
      },
      fetch: (_, __) async => null,
      install: (_) async => false,
    );

    await tester.pumpWidget(host(() async => null, ui: ui));
    await openSystemTab(tester);

    await tester.tap(find.text('CHECK FOR UPDATES NOW'));
    await tester.pumpAndSettle();

    expect(ui.isOpen, isTrue, reason: 'the sheet is where the offer lives now');
    expect(checks, 1, reason: 'the row must not run a second check behind the sheet');
    expect(find.textContaining('v0.2.2+22'), findsWidgets);
  });
}
