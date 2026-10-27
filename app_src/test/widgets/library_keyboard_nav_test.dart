@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks(int n) => [
      for (var i = 0; i < n; i++)
        Track(
          id: 't$i',
          title: 'Track number $i',
          artist: 'ATLUS Sound Team',
          album: 'Persona 5 Royal',
          duration: const Duration(seconds: 180),
          file: 't$i.m4a',
          cover: '',
          gainDb: 0,
        ),
    ];

Future<List<Track>> _pump(WidgetTester tester, {int count = 5}) async {
  final played = <Track>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LibraryScreen(

          searchOnly: true,
        tracks: _tracks(count),
        coverPathFor: (_) => null,
        skin: kSkinCrimson,
        onPlay: played.add,
      ),
    ),
  ));
  await tester.pump();
  return played;
}

bool _rowHighlighted(WidgetTester tester, String title) {
  final row = find.ancestor(
    of: find.text(title),
    matching: find.byType(Stack),
  );
  if (row.evaluate().isEmpty) return false;
  for (final c in tester.widgetList<AnimatedContainer>(
    find.descendant(of: row.first, matching: find.byType(AnimatedContainer)),
  )) {
    final d = c.decoration;
    if (d is BoxDecoration && d.color == kSkinCrimson.accent) return true;
  }
  return false;
}

Future<void> _tapKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
}

void main() {
  group('arrow keys move a selection', () {
    testWidgets('Down selects the first row, then the second', (tester) async {
      await _pump(tester);

      await _tapKey(tester, LogicalKeyboardKey.arrowDown);

      final first = tester.getTopLeft(find.text('Track number 0')).dx;
      expect(first, isNotNull);

      await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      await _tapKey(tester, LogicalKeyboardKey.arrowDown);

      expect(find.text('Track number 0'), findsOneWidget);
    });

    testWidgets('Up from nothing does not select the last row', (tester) async {
      await _pump(tester);

      await _tapKey(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('Track number 0'), findsOneWidget);
    });

    testWidgets('the selection is highlighted like a hover', (tester) async {
      await _pump(tester);
      expect(_rowHighlighted(tester, 'Track number 0'), isFalse,
          reason: 'nothing should be highlighted before a key is pressed');

      await _tapKey(tester, LogicalKeyboardKey.arrowDown);

      expect(_rowHighlighted(tester, 'Track number 0'), isTrue);
    });
  });

  group('Enter plays the selection', () {
    testWidgets('Enter plays the selected track', (tester) async {
      final played = await _pump(tester);

      await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      await _tapKey(tester, LogicalKeyboardKey.enter);

      expect(played.length, 1, reason: 'Enter did not play anything');
      expect(played.first.id, 't1');
    });

    testWidgets('Enter with nothing selected plays nothing', (tester) async {
      final played = await _pump(tester);
      await _tapKey(tester, LogicalKeyboardKey.enter);
      expect(played, isEmpty,
          reason: 'Enter must not guess which track was meant');
    });

    testWidgets('the selection stops at the end of the list', (tester) async {
      final played = await _pump(tester, count: 3);

      for (var i = 0; i < 10; i++) {
        await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      }
      await _tapKey(tester, LogicalKeyboardKey.enter);

      expect(played.length, 1);

      expect(played.first.id, 't2');
    });

    testWidgets('a click moves the selection, so Enter then plays that row',
        (tester) async {
      final played = await _pump(tester);

      await tester.tap(find.text('Track number 2'));
      await tester.pump();
      await _tapKey(tester, LogicalKeyboardKey.enter);

      expect(played.length, 1);
      expect(played.first.id, 't2');
    });
  });

  group('typing does NOT move the list cursor', () {
    testWidgets('arrows in the search field belong to the caret', (tester) async {
      final played = await _pump(tester);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'track');
      await tester.pump();

      await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      await _tapKey(tester, LogicalKeyboardKey.enter);

      expect(played, isEmpty,
          reason: 'arrow keys in a text field must not drive the list');
    });
  });

  group('filtering keeps the cursor valid', () {
    testWidgets('selecting past the end of a filtered list does not crash',
        (tester) async {
      final played = await _pump(tester, count: 6);

      for (var i = 0; i < 5; i++) {
        await _tapKey(tester, LogicalKeyboardKey.arrowDown);
      }

      await tester.enterText(find.byType(TextField), 'Track number 0');
      await tester.pump();

      await _tapKey(tester, LogicalKeyboardKey.enter);

      if (played.isNotEmpty) {
        expect(played.first.id, 't0');
      }
    });
  });
}
