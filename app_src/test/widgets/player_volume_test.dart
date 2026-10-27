@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/audio_panel.dart';
import 'package:sonarar/widgets/track_actions.dart';

Track _track() => Track(
      id: 't1',
      title: 'A test track',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5 Royal',
      duration: const Duration(seconds: 180),
      file: 't1.m4a',
      cover: '',
      gainDb: 0,
    );

AppState _state() => AppState();

Future<List<double>> _pump(WidgetTester tester, {double volume = 1.0}) async {
  final changes = <double>[];

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: PlayerScreen(
        state: _state(),
        track: _track(),
        volume: volume,
        onVolume: changes.add,

        panel: PlayerPanel.audio,

        audioContent: AudioPanel(
          skin: kSkinCrimson,
          volume: volume,
          onVolume: changes.add,
          muted: volume <= 0.001,
        ),
      ),
    ),
  ));

  await tester.pumpAndSettle();
  return changes;
}

void main() {
  group('the volume slider is present and acts', () {
    testWidgets('the AUDIO door shows a slider', (tester) async {
      await _pump(tester);
      expect(find.byKey(AudioPanel.volumeKey), findsOneWidget,
          reason: 'the phone has no other way to set the volume');
    });

    testWidgets('dragging the slider reports a new level', (tester) async {
      final changes = await _pump(tester, volume: 1.0);
      await tester.drag(find.byKey(AudioPanel.volumeKey), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(changes, isNotEmpty, reason: 'dragging did nothing');
      expect(changes.last, lessThan(1.0));
    });

    testWidgets('no AUDIO button when there is nowhere to send it',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Material(child: PlayerScreen(state: _state(), track: _track())),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      expect(find.byKey(TrackActions.audioButtonKey), findsNothing);
    });
  });

  group('the icon doubles as mute', () {
    testWidgets('tapping the speaker mutes', (tester) async {
      final changes = await _pump(tester, volume: 0.6);
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();
      expect(changes, contains(0.0));
    });

    testWidgets('tapping it again restores, so a mute is never a trap',
        (tester) async {
      final changes = await _pump(tester, volume: 0.0);
      await tester.tap(find.byIcon(Icons.volume_off_rounded));
      await tester.pumpAndSettle();
      expect(changes, contains(1.0));
    });

    testWidgets('a muted level shows the muted icon', (tester) async {
      await _pump(tester, volume: 0.0);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });
  });
}
