library;

// The Home tab of Personalization was the only tab with nothing to look at: a
// band, a sentence in English explaining why NOW was missing from the list, and
// eight rows of arrows. The preview above it was the same static sample it drew
// for Themes and Look, so pressing an arrow changed a list and left the picture
// exactly as it was.
//
// This file measures the three things that fix turns into: the picture is the
// page (a section that moves, moves there), a section that is off says so on its
// own row and leaves the picture, and RESET exists only once there is something
// to undo. Plus the one thing no ARB gate can see: a screen that is otherwise
// translated in five languages had four sentences of English baked into it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/screens/personalize_screen.dart';

Future<AppState> _open(
  WidgetTester tester,
  String tab, {
  Locale? locale,
  bool wearingTheme = false,
}) async {
  tester.view.physicalSize = const Size(420, 1200) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  if (wearingTheme) state.applyPreset(state.allPresets.first);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PersonalizeScreen(
          state: state,
          onSaveTheme: (_) {},
          onDeleteTheme: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  if (tab != 'themes') {
    await tester.tap(find.byKey(Key('personalize-tab-$tab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
  return state;
}

/// How far down the page a section's name sits inside the preview card. Order is
/// read from where the pixels land, not from what the state says, because the
/// state was already right while the picture was wrong.
double _previewY(WidgetTester tester, String section) =>
    tester.getTopLeft(find.byKey(ValueKey('preview-section-$section'))).dy;

Finder _row(String section) => find.byKey(ValueKey('home-row-$section'));

Finder _inRow(String section, Finder matching) =>
    find.descendant(of: _row(section), matching: matching);

void main() {
  testWidgets('the Home preview is the page: reordering moves the name in it', (
    tester,
  ) async {
    await _open(tester, 'home');

    expect(
      _previewY(tester, 'continueListening'),
      lessThan(_previewY(tester, 'recentlyAdded')),
      reason:
          'The shipped order is not drawn in the shipped order, so nothing '
          'below can be measuring a reorder.',
    );

    // The down arrow on the first section.
    await tester.tap(
      _inRow('continueListening', find.byType(IconButton)).at(1),
    );
    await tester.pump();

    expect(
      _previewY(tester, 'recentlyAdded'),
      lessThan(_previewY(tester, 'continueListening')),
      reason:
          'Pressing "move down" changed the list and left the miniature '
          'untouched: the picture is a sample, so the tab shows no result of '
          'the thing it exists to change.',
    );
  });

  testWidgets('a section that is off says HIDDEN and leaves the picture', (
    tester,
  ) async {
    await _open(tester, 'home');

    await tester.tap(_inRow('continueListening', find.byType(Switch)));
    await tester.pump();

    expect(
      find.text('HIDDEN'),
      findsOneWidget,
      reason:
          'A section switched off looks exactly like one switched on. The '
          'switch position was the only clue and it sits at the far end of the '
          'row, away from the name it is about.',
    );
    expect(
      find.byKey(const ValueKey('preview-section-continueListening')),
      findsNothing,
      reason: 'The hidden section is still drawn on the page being previewed.',
    );
    expect(
      find.byKey(const ValueKey('preview-section-rediscover')),
      findsOneWidget,
      reason:
          'Hiding one section did not make room for the next: the picture '
          'is not the page, it is a list of the first two names.',
    );
  });

  testWidgets('RESET appears once the order differs and puts it back', (
    tester,
  ) async {
    await _open(tester, 'home');

    expect(
      find.text('RESET ORDER'),
      findsNothing,
      reason:
          'A reset button is on screen before anything was changed, so it '
          'cannot mean "undo what I just did".',
    );

    await tester.tap(
      _inRow('continueListening', find.byType(IconButton)).at(1),
    );
    await tester.pump();
    expect(
      find.text('RESET ORDER'),
      findsOneWidget,
      reason:
          'Eight rows of arrows and no way back: a reorder made by accident '
          'is permanent.',
    );

    await tester.tap(find.text('RESET ORDER'));
    await tester.pump();

    expect(
      _previewY(tester, 'continueListening'),
      lessThan(_previewY(tester, 'recentlyAdded')),
      reason: 'RESET did not restore the shipped order.',
    );
    expect(
      find.text('RESET ORDER'),
      findsNothing,
      reason: 'RESET is still offered after everything was put back.',
    );
  });

  testWidgets('the Home tab speaks the language in force', (tester) async {
    await _open(tester, 'home', locale: const Locale('fi'));

    expect(
      find.textContaining('page header'),
      findsNothing,
      reason:
          'The Home tab is explaining itself in English inside a Finnish '
          'app: the sentence was a literal, so no ARB gate could see it.',
    );
    expect(
      find.text('SIVUN OTSIKKO'),
      findsOneWidget,
      reason:
          'The locked NOW row does not say what NOW is in the language in '
          'force, so the row explains nothing to most of the people reading it.',
    );
  });

  testWidgets('the Themes tab speaks the language in force too', (
    tester,
  ) async {
    await _open(
      tester,
      'themes',
      locale: const Locale('fi'),
      wearingTheme: true,
    );

    expect(
      find.textContaining('OVERRIDE writes this look'),
      findsNothing,
      reason:
          'The OVERRIDE note is still English: it names the theme you are '
          'wearing, so it is read every time someone decides between the two '
          'buttons beside it.',
    );
    expect(
      find.textContaining('OVERRIDE kirjoittaa'),
      findsOneWidget,
      reason:
          'The note that explains what OVERRIDE does is not translated, '
          'which leaves the one explanation of a destructive button unreadable.',
    );
  });

  test('the screen keeps no prose of its own', () {
    final source = File('lib/screens/personalize_screen.dart')
        .readAsStringSync();
    const baked = [
      'NOW stays at the top',
      'OVERRIDE writes this look into',
      "art folder'",
      'FRAME \$at/\$total',
    ];
    for (final literal in baked) {
      expect(
        source.contains(literal),
        isFalse,
        reason:
            'personalize_screen.dart still carries the English literal '
            '"$literal". Every one of these is a sentence or a label a user '
            'reads, and the screen is translated into five languages; the ARB '
            'gate counts keys, so a literal is invisible to it.',
      );
    }
  });
}
