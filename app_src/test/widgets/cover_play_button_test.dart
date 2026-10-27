@Tags(['slow'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/cover_play_button.dart';

Future<int> _pump(
  WidgetTester tester, {
  VoidCallback? onTogglePlay,
  bool isPlaying = false,
}) async {
  var taps = 0;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: CoverPlayButton(
          skin: kSkinCrimson,
          cover: null,
          size: 56,
          isPlaying: isPlaying,
          onTogglePlay: onTogglePlay ?? () => taps++,
        ),
      ),
    ),
  ));
  await tester.pump();
  return taps;
}

IconData? _glyph(WidgetTester tester) {
  final icons = tester.widgetList<Icon>(find.byType(Icon));
  for (final i in icons) {
    if (i.icon == Icons.play_arrow_rounded) return Icons.play_arrow_rounded;
    if (i.icon == Icons.pause_rounded) return Icons.pause_rounded;
  }
  return null;
}

void main() {
  group('hover shows the glyph, and only on hover', () {
    testWidgets('nothing is drawn at rest', (tester) async {
      await _pump(tester);
      expect(_glyph(tester), isNull,
          reason: 'a glyph shown permanently is a button nobody asked for');
    });

    testWidgets('hovering draws the play glyph', (tester) async {
      await _pump(tester);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverPlayButton)));
      await tester.pump();

      expect(_glyph(tester), Icons.play_arrow_rounded);
    });

    testWidgets('hovering does NOT act — no tap fires', (tester) async {
      var taps = 0;
      await _pump(tester, onTogglePlay: () => taps++);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverPlayButton)));
      await tester.pump();
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();

      expect(taps, 0, reason: 'hover must not start playback');
    });
  });

  group('the glyph is truthful', () {
    testWidgets('a paused track shows PLAY', (tester) async {
      await _pump(tester, isPlaying: false);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverPlayButton)));
      await tester.pump();

      expect(_glyph(tester), Icons.play_arrow_rounded);
    });

    testWidgets('a playing track shows PAUSE', (tester) async {
      await _pump(tester, isPlaying: true);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverPlayButton)));
      await tester.pump();

      expect(_glyph(tester), Icons.pause_rounded,
          reason: 'a running track must offer to pause it');
    });
  });

  group('clicking acts', () {
    testWidgets('a click fires the callback once', (tester) async {
      var taps = 0;
      await _pump(tester, onTogglePlay: () => taps++);

      await tester.tap(find.byType(CoverPlayButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('with no callback the cover is inert', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CoverPlayButton(
              skin: kSkinCrimson,
              cover: null,
              size: 46,
            ),
          ),
        ),
      ));
      await tester.pump();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(CoverPlayButton)));
      await tester.pump();

      expect(_glyph(tester), isNull,
          reason: 'no callback means no glyph and no promise');
    });
  });
}
