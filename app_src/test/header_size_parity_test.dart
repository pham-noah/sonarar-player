library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/slab.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'a',
      album: 'b',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

double _fontSize(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final size = paragraph.text.style?.fontSize;
  expect(size, isNotNull, reason: '"$text" has no explicit font size to compare');
  return size!;
}

Future<void> _pumpLibrary(WidgetTester tester, LayoutKind kind) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final skin = skinFor(SkinId.crimson);
  await tester.pumpWidget(MaterialApp(
    home: PresentationScope(
      presentation: presentationFor(kind, skin),
      child: Scaffold(
        body: LibraryScreen(
          entryToken: 0,
          tracks: [_t('a'), _t('b')],
          coverPathFor: (_) => null,
          skin: skin,

          headerScrollsAway: true,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  for (final kind in [LayoutKind.solid, LayoutKind.glass]) {
    testWidgets('${kind.name}: the Library title is the same size as a tab title',
        (tester) async {
      await _pumpLibrary(tester, kind);
      final library = _fontSize(tester, 'LIBRARY');

      await tester.pumpWidget(MaterialApp(
        home: PresentationScope(
          presentation: presentationFor(kind, skinFor(SkinId.crimson)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ScreenTitle(skin: skinFor(SkinId.crimson), text: 'SETTINGS'),
            ),
          ),
        ),
      ));
      await tester.pump();
      final tab = _fontSize(tester, 'SETTINGS');

      expect(library, tab,
          reason: 'on ${kind.name} the Library title renders at ${library}px while every other tab '
              'renders at ${tab}px — the titles must be one size');
    });
  }

  testWidgets('Persona keeps its accent band, which is its own device', (tester) async {
    await _pumpLibrary(tester, LayoutKind.persona);
    expect(find.text('LIBRARY'), findsOneWidget,
        reason: 'Persona still has a Library heading');
    expect(find.byType(ScreenTitle), findsNothing,
        reason: 'Persona draws its heading as a band, not as a plain title');
  });
}
