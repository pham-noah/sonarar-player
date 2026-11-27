library;

// What a finger and a screen reader can actually reach on Personalization, and
// what a row says when the move it offers cannot happen. The failures these
// tests were written against:
//
//   - Every theme row and every full-width button was a bare `GestureDetector`:
//     it announced its name as plain text, so a screen reader said "Crimson,
//     built in" and never "button"; the row was 42dp tall.
//   - OVERRIDE sat bright and enabled under a note that said there was no theme
//     to override.
//   - The art tab's five place tiles wanted 568dp on a 412dp phone: the fourth
//     was cut mid-word and the fifth was off the edge, with no sign it existed.
//   - The first Home row's up arrow and the last row's down arrow were painted
//     like live arrows while doing nothing.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/personalize_screen.dart';

Future<void> _open(WidgetTester tester, String tab) async {
  tester.view.physicalSize = const Size(412, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PersonalizeScreen(
          state: state,
          prefs: AppPrefs.initial,
          onPrefsChanged: (_) {},
          // Wired as the app wires it: a screen with fewer buttons than the app
          // passes in is a screen nobody can reach.
          onSaveTheme: (_) {},
          onApplyTheme: (_) {},
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
}

/// Every `Semantics` widget with this label, as the data it would announce.
List<SemanticsProperties> _named(WidgetTester tester, String label) => [
  for (final e in find.byType(Semantics).evaluate())
    if ((e.widget as Semantics).properties.label == label)
      (e.widget as Semantics).properties,
];

void main() {
  testWidgets('a theme row is a button that says it wears the theme', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, 'themes');

    final built = AppState().allPresets;
    expect(built, isNotEmpty);
    for (final preset in built) {
      final found = _named(tester, 'Wear ${preset.name}');
      expect(
        found,
        hasLength(1),
        reason:
            'the ${preset.name} row announced its name and not what '
            'pressing it does',
      );
      expect(found.single.button, isTrue);
    }

    // Nothing is worn, so nothing claims to be.
    expect(
      [for (final p in built) ..._named(tester, 'Wear ${p.name}')]
          .where((s) => s.selected == true),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('the buttons are buttons, and the dead one says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, 'themes');

    final newTheme = _named(tester, 'NEW THEME');
    expect(newTheme, hasLength(1));
    expect(newTheme.single.button, isTrue);
    expect(newTheme.single.enabled ?? true, isTrue);

    // No theme is worn: overriding would have nothing to change, which the note
    // underneath already says. The button has to agree with the note.
    final override = _named(tester, 'OVERRIDE');
    expect(override, hasLength(1));
    expect(
      override.single.enabled,
      isFalse,
      reason:
          'a note saying a button cannot work, above a button that looks '
          'like it can, means the note loses',
    );
    expect(override.single.onTap, isNull);
    handle.dispose();
  });

  testWidgets('every place on the art tab is on the screen, not off its edge', (
    tester,
  ) async {
    await _open(tester, 'art');
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    const places = ['everywhere', 'home', 'library', 'search', 'player'];
    for (final place in places) {
      final tile = find.byKey(Key('scope-$place'));
      expect(
        tile,
        findsOneWidget,
        reason:
            '$place is a place you can give a '
            'picture to',
      );
      final rect = tester.getRect(tile);
      expect(
        rect.right <= width + 0.5 && rect.left >= -0.5,
        isTrue,
        reason:
            '$place sits at ${rect.left.round()}..${rect.right.round()} on '
            'a ${width.round()}dp screen: a tile past the edge is a place that '
            'cannot be given a picture',
      );
    }
  });

  testWidgets('an arrow with nowhere to go is drawn as a dead end', (
    tester,
  ) async {
    await _open(tester, 'home');

    final rows = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('home-row-'),
        )
        .evaluate()
        .map((e) => e.widget.key! as ValueKey<String>)
        .toList();
    expect(rows.length, greaterThan(1));

    List<IconButton> arrowsOf(ValueKey<String> row) => tester
        .widgetList<IconButton>(
          find.descendant(
            of: find.byKey(row),
            matching: find.byType(IconButton),
          ),
        )
        .toList();

    final first = arrowsOf(rows.first);
    expect(
      first.first.onPressed,
      isNull,
      reason:
          'the top row has nothing '
          'above it to move past',
    );
    final last = arrowsOf(rows.last);
    expect(
      last.last.onPressed,
      isNull,
      reason:
          'the bottom row has nothing '
          'below it to move past',
    );
    // A row in the middle can go both ways, or the arrows mean something else.
    final middle = arrowsOf(rows[rows.length ~/ 2]);
    expect(middle.first.onPressed, isNotNull);
    expect(middle.last.onPressed, isNotNull);
  });
}
