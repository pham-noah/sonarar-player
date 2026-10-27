@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';

Track _t() => Track(
      id: 'a', title: 'Rivers In the Desert', artist: 'ATLUS Sound Team',
      album: 'P5', duration: const Duration(minutes: 4), file: 'a.opus',
      cover: '', gainDb: null,
    );

Future<void> _pump(WidgetTester tester, {VoidCallback? onLyrics}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: PlayerScreen(
        state: AppState(),
        track: _t(),
        hasWhy: true,
        hasQueue: true,
        hasTrackPanel: true,
        onSleep: (_) {},
        onLyrics: onLyrics ?? () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the lyrics button is in the UP NEXT row', (tester) async {
    await _pump(tester);
    expect(find.byKey(PlayerScreen.lyricsButtonKey), findsOneWidget,
        reason: 'the lyrics button is not in the up-next row');
  });

  testWidgets('both sit on the RIGHT side, button after the up-next text',
      (tester) async {
    await _pump(tester);
    final button = tester.getRect(find.byKey(PlayerScreen.lyricsButtonKey));

    final label = find.byWidgetPredicate(
      (w) => w is Text && (w.data == 'UP NEXT' || w.data == 'END OF QUEUE'),
    );
    expect(label, findsOneWidget);
    final labelRect = tester.getRect(label);
    final width = tester.view.physicalSize.width / 3.0;

    expect(labelRect.right, greaterThan(width * 0.75),
        reason: 'the up-next text is not on the right side');

    expect(button.left, lessThan(labelRect.left),
        reason: 'the button should sit to the left of the up-next text');
  });

  testWidgets('it toggles', (tester) async {
    var taps = 0;
    await _pump(tester, onLyrics: () => taps++);
    await tester.tap(find.byKey(PlayerScreen.lyricsButtonKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('absent when there is no mode to open', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: PlayerScreen(
          state: AppState(), track: _t(),
          audioContent: const SizedBox(height: 40),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(PlayerScreen.lyricsButtonKey), findsNothing);
  });
}
