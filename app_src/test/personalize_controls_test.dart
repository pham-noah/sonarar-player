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
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/theme_preset.dart';

Future<AppState> _open(
  WidgetTester tester,
  String tab, {
  AppState? withState,
}) async {
  tester.view.physicalSize = const Size(412, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = withState ?? AppState();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PersonalizeScreen(
          state: state,
          prefs: AppPrefs.initial,
          onPrefsChanged: (_) {},
          // Wired as `main.dart` wires it. A stub that does nothing would let
          // a broken delete pass: the screen calls back, and the callback is
          // what actually removes the theme.
          onSaveTheme: (name) => state.setUserPresets([
            ...state.userPresets,
            ThemePreset(id: name, name: name, skinId: SkinId.abyss),
          ]),
          onApplyTheme: state.applyPreset,
          onDeleteTheme: (preset) => state.setUserPresets([
            for (final p in state.userPresets)
              if (p.id != preset.id) p,
          ]),
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

  testWidgets('the tabs say they are tabs, and which one is showing', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, 'art');

    // By key, not by label: the art tab's place strip also has a tile named
    // HOME, and a label is not an identity.
    for (final tab in const ['themes', 'look', 'art', 'home']) {
      final node = tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(Key('personalize-tab-$tab')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties;
      expect(node.label, isNotNull, reason: '$tab tab has no name');
      expect(node.button, isTrue, reason: '$tab tab is not a button');
      expect(
        node.selected,
        tab == 'art',
        reason: 'the $tab tab is wrong about which page is showing',
      );
    }
    handle.dispose();
  });

  testWidgets('deleting a saved theme asks first, and cancel keeps it', (
    tester,
  ) async {
    final state = AppState()
      ..setUserPresets(const [
        ThemePreset(id: 'mine', name: 'Late Night', skinId: SkinId.abyss),
      ]);
    await _open(tester, 'themes', withState: state);

    expect(find.text('Late Night'), findsOneWidget);

    // Cancel: the theme is still there.
    await tester.tap(find.bySemanticsLabel('Delete Late Night'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Late Night"'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('Late Night'), findsOneWidget);
    expect(state.userPresets, hasLength(1));

    // Confirm: it goes.
    await tester.tap(find.bySemanticsLabel('Delete Late Night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(state.userPresets, isEmpty);
    expect(find.text('Late Night'), findsNothing);
  });
}
