import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_bundle.dart';
import 'package:sonarar/art/skin_art.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/screens/personalize_screen.dart';
import 'package:sonarar/theme/personalization.dart';

void main() {
  late AppState state;

  setUp(() => state = AppState());

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for every section at once: the screen grew a LAYOUT and a
    // SONG LIST block, and a phone-height viewport pushes HOME below the fold.
    tester.view.physicalSize = const Size(430, 2600) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: PersonalizeScreen(state: state),
    ));
    await tester.pump();
  }

  testWidgets('the screen is four tabs, each showing its own part', (tester) async {
    await pump(tester);

    for (final tab in ['look', 'art', 'home', 'themes']) {
      expect(find.byKey(Key('personalize-tab-$tab')), findsOneWidget,
          reason: 'the $tab tab is missing');
    }

    // THEMES is where you land: the theme is the container the rest edit.
    expect(find.text('LAYOUT'), findsNothing,
        reason: 'the theme tab is the first thing you see, not the look tab');

    await tester.tap(find.byKey(const Key('personalize-tab-look')));
    await tester.pumpAndSettle();
    expect(find.text('LAYOUT'), findsOneWidget);
    expect(find.text('SONG LIST'), findsOneWidget);
    expect(find.text('EVERYWHERE'), findsNothing,
        reason: 'the picture slot lives in the ART tab, not the look tab');

    await tester.tap(find.byKey(const Key('personalize-tab-art')));
    await tester.pumpAndSettle();
    expect(find.text('EVERYWHERE'), findsOneWidget,
        reason: 'the screen lost the "one picture for all places" option');
    expect(find.text('PICTURE FOR'), findsOneWidget,
        reason: 'the picture and the folders that fill it are one tab');
    expect(find.text('BACKDROP'), findsNothing,
        reason: 'a photo is a picture like any other — it lost its own section');
    expect(find.text('LAYOUT'), findsNothing);

    await tester.tap(find.byKey(const Key('personalize-tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE LISTENING'), findsOneWidget);
    expect(find.text('NOW stays at the top — it is the page header, not a section.'),
        findsOneWidget);
    expect(find.text('NOW'), findsNothing);
  });

  testWidgets('one ART tab holds the picture and the folders under it',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('personalize-tab-art')));
    await tester.pumpAndSettle();

    expect(find.text('EVERYWHERE'), findsOneWidget);
    expect(find.text('NO PICTURE'), findsOneWidget,
        reason: 'the place chips and the picture choices live in the same tab');

    await tester.scrollUntilVisible(
      find.text('ART FOLDERS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('ART FOLDERS'), findsOneWidget,
        reason: 'the folders that fill the picture slot sit under it, not in a tab of their own');
  });

  testWidgets('hiding a section keeps its row on screen and marks it hidden', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('personalize-tab-home')));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('home-row-recap'));
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pump();

    expect(state.personalization.home.hidden, contains(HomeSection.recap));
    expect(find.text('RECAP'), findsOneWidget, reason: 'a hidden section must stay listed to be turned back on');
  });

  testWidgets('moving a section up writes the new order', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('personalize-tab-home')));
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('home-row-recap'));
    await tester.scrollUntilVisible(row, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.keyboard_arrow_up_rounded)));
    await tester.pump();

    final order = state.personalization.home.all;
    expect(order.indexOf(HomeSection.recap),
        lessThan(HomeLayout.defaultOrder.indexOf(HomeSection.recap)));
  });

  testWidgets('picking an accent writes it and keeps the source', (tester) async {
    await pump(tester);

    // The screen lands on THEMES now; the accent lives under LOOK.
    await tester.tap(find.byKey(const Key('personalize-tab-look')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PICK'));
    await tester.pump();

    final swatch = find.byType(GestureDetector).at(0);
    expect(swatch, findsOneWidget);
    expect(state.personalization.accent.source, AccentSource.manual);
  });

  testWidgets('a folder with two pictures gives a place both, and one is worn',
      (tester) async {
    // A picture has to exist on disk for a tile to draw; a 1x1 PNG is enough.
    final dir = Directory.systemTemp.createTempSync('sonarar-art-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final one = File('${dir.path}/one.png')
      ..writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ));
    final two = File('${dir.path}/two.png')..writeAsBytesSync(one.readAsBytesSync());
    state.setArtBundles([
      ArtBundle(
        name: 'TWO',
        set: SkinArtSet(SkinId.abyss, [
          SkinArt(key: 'TWO/one.png', assetPath: 'file:${one.path}', aspect: 1),
          SkinArt(key: 'TWO/two.png', assetPath: 'file:${two.path}', aspect: 1),
        ]),
      ),
    ]);

    await pump(tester);
    await tester.tap(find.byKey(const Key('personalize-tab-art')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle();

    // The folder renders both pictures as tappable frames.
    expect(find.byKey(const Key('folder-frame-TWO/two.png')), findsOneWidget,
        reason: 'a folder of two pictures must offer both, not just the first');

    await tester.tap(find.byKey(const Key('folder-frame-TWO/two.png')));
    await tester.pumpAndSettle();

    expect(state.personalization.surfaces[SurfaceId.library]?.art, 'TWO/two.png',
        reason: 'the place wears the picture that was tapped');
  });

  testWidgets('a picture from the phone is offered as a place picture too',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('personalize-tab-art')));
    await tester.pumpAndSettle();

    expect(find.text('ADD PICTURE'), findsWidgets,
        reason: 'one door for pictures: the slot and the folders share it');
  });
}
