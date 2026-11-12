library;

import 'package:flutter/material.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  int count = 5,
  int searchRequest = 0,
  VoidCallback? onChooseFolder,
}) async {
  tester.view.physicalSize = const Size(400, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: LibraryScreen(view: LibraryScreenView(
        tracks: _tracks(count),
        coverPathFor: (_) => null,
        skin: kSkinCrimson,
        libraryRoot: '/storage/emulated/0/Music/Sonarar',
        searchRequest: searchRequest,
        onChooseFolder: onChooseFolder,
        onPlay: (_) {},
      )),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('the library can be searched from a phone', () {
    testWidgets('the header carries a search control', (tester) async {
      await _pump(tester);

      expect(find.byIcon(Icons.search_rounded), findsOneWidget,
          reason: 'search exists but nothing on a phone opens it');
    });

    testWidgets('the search control opens the search screen', (tester) async {
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget,
          reason: 'the search screen is open and its field is in the tree');
      expect(find.text('Track number 0'), findsOneWidget);
    });

    testWidgets('typing narrows the list to the match', (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'number 3');
      await tester.pump();

      expect(find.text('Track number 3'), findsOneWidget);
      expect(find.text('Track number 0'), findsNothing);
    });

    testWidgets('the close control returns to the library', (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget,
          reason: 'the header is back, so search can be opened again');
    });

    testWidgets('a search request opens search and focuses the field',
        (tester) async {
      await _pump(tester, searchRequest: 0);
      await _pump(tester, searchRequest: 1);

      expect(find.byType(TextField), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue,
          reason: 'a keyboard search that does not focus the field is a no-op');
    });

    testWidgets('nothing is offered to search when there is no library',
        (tester) async {
      await _pump(tester, count: 0);

      expect(find.byIcon(Icons.search_rounded), findsNothing,
          reason: 'a search over nothing is a dead end');
    });
  });

  group('an empty library offers the action that fixes it', () {
    testWidgets('the empty state has a folder button', (tester) async {
      var chosen = 0;
      await _pump(tester, count: 0, onChooseFolder: () => chosen++);

      expect(find.text('CHOOSE A FOLDER'), findsOneWidget);
      expect(find.textContaining('Expected at'), findsNothing,
          reason: 'a path is not an instruction a user can act on');

      await tester.tap(find.text('CHOOSE A FOLDER'));
      await tester.pump();

      expect(chosen, 1);
    });

    testWidgets('the folder button is absent when nothing can open it',
        (tester) async {
      await _pump(tester, count: 0);

      expect(find.text('CHOOSE A FOLDER'), findsNothing,
          reason: 'a button that goes nowhere is worse than none');
    });
  });
}
