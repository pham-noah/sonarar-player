@Tags(['slow'])
library;

import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/cover_button.dart';

final _bytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x72, 0xB6, 0x0D, 0x24, 0x00, 0x00, 0x00,
  0x14, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xFC, 0xCF, 0xC0, 0xF0,
  0x9F, 0x81, 0x81, 0x81, 0x89, 0x01, 0x0A, 0x00, 0x1E, 0x04, 0x02, 0x01,
  0x9E, 0xD8, 0xAA, 0x67, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _pump(
  WidgetTester tester, {
  required bool playing,
  VoidCallback? onPlayPause,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: CoverButton(
          skin: kSkinAbyss,
          cover: MemoryImage(_bytes),
          playing: playing,
          onPlayPause: onPlayPause,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('the overlay only exists while hovered', () {
    testWidgets('no play glyph by default — the art is unobstructed', (tester) async {
      await _pump(tester, playing: false, onPlayPause: () {});

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });

    testWidgets('hovering reveals play when paused', (tester) async {
      await _pump(tester, playing: false, onPlayPause: () {});
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverButton)));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('hovering reveals PAUSE when playing, not play', (tester) async {
      await _pump(tester, playing: true, onPlayPause: () {});
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverButton)));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('leaving hides it again', (tester) async {
      await _pump(tester, playing: false, onPlayPause: () {});
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(CoverButton)));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await gesture.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  group('clicking toggles', () {
    testWidgets('a tap calls onPlayPause exactly once', (tester) async {
      var calls = 0;
      await _pump(tester, playing: false, onPlayPause: () => calls++);
      await tester.tap(find.byType(CoverButton));
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('no callback means no overlay and no error', (tester) async {
      await _pump(tester, playing: false, onPlayPause: null);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverButton)));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      await tester.tap(find.byType(CoverButton));
      await tester.pump();
    });
  });

  group('the art is still the art', () {
    testWidgets('the cover renders whether hovered or not', (tester) async {
      await _pump(tester, playing: false, onPlayPause: () {});
      expect(find.byType(Image), findsOneWidget);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverButton)));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a null cover shows the panel colour, not a broken image',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: CoverButton(
              skin: kSkinAbyss,
              cover: null,
              playing: false,
              onPlayPause: () {},
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
