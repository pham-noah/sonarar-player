library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';

Track _t(int i) => Track(
      id: 't$i',
      title: 'Title $i',
      artist: 'Artist $i',
      album: 'A',
      duration: const Duration(seconds: 90),
      file: 't$i.m4a',
      cover: '',
      gainDb: 0,
    );

Future<void> _pump(WidgetTester tester, PlayerScreen screen) async {
  tester.view.physicalSize = const Size(400, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Material(child: screen)));
  await tester.pumpAndSettle();
}

Future<void> _tapIcon(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a single tap on NEXT calls onNext exactly once', (tester) async {
    var nexts = 0;
    var prevs = 0;
    var shuffles = 0;
    final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);

    await _pump(
      tester,
      PlayerScreen(
        state: state,
        track: _t(0),
        onNext: () => nexts++,
        onPrevious: () => prevs++,
        onShuffle: () => shuffles++,
      ),
    );

    await _tapIcon(tester, Icons.skip_next_rounded);

    expect(nexts, 1,
        reason: 'one tap on next produced $nexts calls to onNext — a doubled tap handler, so every press '
            'skips more than once and the transport "does not work well"');
    expect(prevs, 0, reason: 'tapping next also fired previous');
    expect(shuffles, 0, reason: 'tapping next also fired shuffle');
  });

  testWidgets('a single tap on PREVIOUS calls onPrevious exactly once', (tester) async {
    var prevs = 0;
    final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);

    await _pump(
      tester,
      PlayerScreen(
        state: state,
        track: _t(0),
        onNext: () {},
        onPrevious: () => prevs++,
      ),
    );

    await _tapIcon(tester, Icons.skip_previous_rounded);

    expect(prevs, 1,
        reason: 'one tap on previous produced $prevs calls — see the next-button test');
  });

  testWidgets('the control case: SHUFFLE fires exactly once', (tester) async {
    var shuffles = 0;
    final state = AppState()..attachLibrary([for (var i = 0; i < 6; i++) _t(i)]);

    await _pump(
      tester,
      PlayerScreen(
        state: state,
        track: _t(0),
        onShuffle: () => shuffles++,
      ),
    );

    await _tapIcon(tester, Icons.shuffle_rounded);

    expect(shuffles, 1);
  });
}
