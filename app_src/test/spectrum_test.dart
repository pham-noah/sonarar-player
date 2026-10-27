@Tags(['slow'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/spectrum.dart';

Track _t() => Track(
      id: 't1',
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: 't1.opus',
      cover: '',
      gainDb: null,
    );

TrackSpectrum _spectrum() {
  final bands = TrackSpectrum.kSpectrumBands;
  final frames = <int>[];
  for (var f = 0; f < 10; f++) {
    for (var b = 0; b < bands; b++) {
      frames.add((255 * (f / 9)).round());
    }
  }
  return TrackSpectrum.parse(Uint8List.fromList(frames));
}

void main() {
  group('the format', () {
    test('frames are read at the position, not the frame index', () {
      final s = _spectrum();
      expect(s.frameCount, 10);

      expect(s.at(const Duration(milliseconds: 250)).first,
          (255 * 5 / 9).round());
      expect(s.at(Duration.zero).first, 0);
    });

    test('a position past the end holds the LAST frame rather than throwing', () {
      final s = _spectrum();
      expect(s.at(const Duration(minutes: 5)).first, 255);
    });

    test('a NEGATIVE position is clamped, since a seek can briefly report one', () {
      expect(_spectrum().at(const Duration(seconds: -1)).first, 0);
    });

    test('a TRUNCATED file loses its tail instead of throwing', () {
      final short = TrackSpectrum.parse(Uint8List.fromList(List.filled(17, 200)));
      expect(short.bands, 7);

      expect(short.frameCount, 2);
    });

    test('an empty file is empty, and is not drawn', () {
      final empty = TrackSpectrum.parse(Uint8List(0));
      expect(empty.isEmpty, isTrue);
      expect(empty.at(Duration.zero), isEmpty);
    });
  });

  group('the widget', () {
    testWidgets('draws nothing without a spectrum', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpectrumBars(
            skin: kSkinCrimson,
            spectrum: null,
            position: Duration.zero,
            playing: true,
          ),
        ),
      ));

      expect(
        find.descendant(
          of: find.byType(SpectrumBars),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
        reason: 'an empty bar field is a screen of zeros pretending to be a readout',
      );
    });

    testWidgets('draws when it has data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: SpectrumBars(
              skin: kSkinCrimson,
              spectrum: _spectrum(),
              position: const Duration(milliseconds: 250),
              playing: true,
            ),
          ),
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(SpectrumBars),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('never eats a tap — the transport is over it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 100,
            child: SpectrumBars(
              skin: kSkinCrimson,
              spectrum: _spectrum(),
              position: Duration.zero,
              playing: true,
            ),
          ),
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(SpectrumBars),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });
  });

  group('in the player', () {
    Future<void> pump(WidgetTester tester, {TrackSpectrum? spectrum}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: PlayerScreen(

            state: AppState(),
            track: _t(),
            spectrum: spectrum,
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('no bars when the player is given no spectrum', (tester) async {
      await pump(tester);
      expect(find.byType(SpectrumBars), findsNothing);
    });

    testWidgets('bars are drawn when it is', (tester) async {
      await pump(tester, spectrum: _spectrum());
      expect(find.byType(SpectrumBars), findsOneWidget);
    });
  });
}
