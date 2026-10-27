@Tags(['slow'])
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/widgets/spectrum.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

TrackSpectrum _shaped() {
  const bands = TrackSpectrum.kSpectrumBands;
  const shape = [40, 110, 200, 255, 190, 120, 60];
  final bytes = <int>[];
  for (var f = 0; f < 60; f++) {
    for (var b = 0; b < bands; b++) {
      bytes.add(((shape[b] * (0.72 + 0.28 * ((f % 7) / 6)))).round().clamp(0, 255));
    }
  }
  return TrackSpectrum.parse(Uint8List.fromList(bytes));
}

void main() {
  testWidgets('GOLDEN: the player with the spectrum drawn', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.attachLibrary([_t('t1')]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerScreen(
            state: state,
            track: _t('t1'),
            spectrum: _shaped(),
            playing: true,
            hasWhy: true,
            hasQueue: true,
            hasTrackPanel: true,
            onSleep: (_) {},
            upNextCount: 3,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));

    await tester.pump(const Duration(milliseconds: 16));

    final bars = find.byType(SpectrumBars);
    expect(bars, findsOneWidget);
    final rect = tester.getRect(bars);
    // ignore: avoid_print
    print('BUDGET bars rect=$rect  h=${rect.height.toStringAsFixed(1)} '
        'bottom=${rect.bottom.toStringAsFixed(1)}');

    await expectLater(
      find.byType(PlayerScreen),
      matchesGoldenFile('goldens/spectrum_preview.png'),
    );
  });
}
