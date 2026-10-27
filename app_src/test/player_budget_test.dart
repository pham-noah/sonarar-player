@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';

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

void main() {
  testWidgets('where UP NEXT lands on a phone', (tester) async {
    final state = AppState();
    state.attachLibrary([_t('a'), _t('b'), _t('c')]);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerScreen(
            state: state,
            track: _t('a'),
            hasWhy: true,
            hasQueue: true,
            hasTrackPanel: true,
            upNextCount: 2,
          ),
        ),
      ),
    );
    await tester.pump();

    final screen = tester.getSize(find.byType(PlayerScreen));

    void report(String label, Finder f) {
      if (f.evaluate().isEmpty) return;
      final r = tester.getRect(f.first);
      // ignore: avoid_print
      print('BUDGET ${label.padRight(14)} top=${r.top.toStringAsFixed(0).padLeft(4)}'
          ' h=${r.height.toStringAsFixed(0).padLeft(4)} bottom=${r.bottom.toStringAsFixed(0)}');
    }

    for (final label in ['Beneath the Mask', 'ATLUS Sound Team', 'UP NEXT']) {
      if (find.text(label).evaluate().isEmpty) continue;
      final r = tester.getRect(find.text(label).first);
      // ignore: avoid_print
      print('BUDGET ${label.padRight(18)} top=${r.top.toStringAsFixed(0).padLeft(4)}'
          ' h=${r.height.toStringAsFixed(0).padLeft(4)}');
    }
    report('screen', find.byType(PlayerScreen));

    report('title', find.text('Beneath the Mask'));
    report('up next', find.textContaining('UP NEXT'));
    report('up next sub', find.textContaining('Nothing after this'));
    report('badge', find.byKey(PlayerScreen.contextBadgeKey));

    final upNext = find.textContaining('UP NEXT');
    if (upNext.evaluate().isNotEmpty) {
      final bottom = tester.getRect(upNext).bottom;
      // ignore: avoid_print
      print('BUDGET up-next bottom=$bottom  viewport=${screen.height}'
          '  visible=${bottom <= screen.height}');
    }
    // ignore: avoid_print
    print('BUDGET viewport height = ${screen.height}');

    expect(tester.getRect(find.byType(PlayerScreen)).width, 360);

    expect(tester.getRect(upNext.first).bottom, lessThan(560),
        reason: 'UP NEXT has slipped down the screen again — something above it grew');
  });
}
