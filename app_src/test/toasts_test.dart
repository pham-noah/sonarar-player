library;

// The undo toast is the last thing standing between a mis-tap and a lost
// queue, and its button said "UNDO" in an app that ships five locales — a
// Finnish user read "Tyhjennetty 18 jonosta" with an English button under it,
// which is the kind of half-translation that makes a whole app feel foreign.
//
// This test pins two things about the toast: the label comes from the locale in
// force, and the button actually runs what it was given. Both are cheap to
// break — the label by another hard-coded string, the callback by a toast that
// shows a button and swallows the tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/toasts.dart';

Future<void> _showUndo(WidgetTester tester, String locale, VoidCallback undo) async {
  await tester.pumpWidget(MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => toastUndo(
              context, kSkinAbyss, 'Cleared 18 from the queue', undo),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the undo button speaks the locale in force', (tester) async {
    const expected = {'en': 'UNDO', 'fi': 'KUMOA', 'ja': '元に戻す', 'vi': 'HOÀN TÁC', 'zh': '撤销'};

    for (final entry in expected.entries) {
      await _showUndo(tester, entry.key, () {});
      expect(find.text(entry.value), findsOneWidget,
          reason: 'in ${entry.key} the undo action must read "${entry.value}"; '
              'a hard-coded English label here is what this test exists for');
      // Drain the snackbar before the next locale.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }
  });

  testWidgets('tapping undo runs the work and takes the bar away', (tester) async {
    var undone = 0;
    await _showUndo(tester, 'en', () => undone++);

    expect(find.text('Cleared 18 from the queue'), findsOneWidget);
    await tester.tap(find.text('UNDO'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(undone, 1, reason: 'a visible button that does nothing is worse '
        'than no button: the user believes the queue is back');
    expect(find.text('UNDO'), findsNothing,
        reason: 'the bar must close on tap, or the next tap undoes again');
  });
}
