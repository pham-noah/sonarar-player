@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/queue_screen.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

void main() {
  testWidgets('tapping a queued track makes it the current track',
      (tester) async {
    final state = AppState();
    state.attachLibrary(List.generate(12, (i) => _t('t$i')));

    expect(state.currentTrack!.id, 't0');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(

          body: QueuePanel(
            state: state,

            onPlay: (t) => state.playTrackNow(t.id),
          ),
        ),
      ),
    );
    await tester.pump();

    final row = find.text('Title t2');
    await tester.scrollUntilVisible(row, 60,
        scrollable: find.byType(Scrollable).first);
    expect(row, findsWidgets, reason: 't2 must be reachable under UP NEXT');

    await tester.pumpAndSettle();

    await tester.tap(row.first);
    await tester.pump();

    expect(state.currentTrack!.id, 't2',
        reason: 'tapping a queued row must start that track');
  });

  testWidgets('the playing row is not a tap target', (tester) async {
    final state = AppState();
    state.attachLibrary(List.generate(6, (i) => _t('t$i')));

    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(

          body: QueuePanel(
            state: state,
            onPlay: (_) => taps++,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Title t0').first);
    await tester.pump();

    expect(taps, 0, reason: 'the current track must not be re-selectable');
    expect(state.currentTrack!.id, 't0');
  });
}
