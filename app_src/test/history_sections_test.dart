library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/play_log.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/history_screen.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(int i) => Track(
      id: 't$i',
      title: 'Title $i',
      artist: 'Artist $i',
      album: 'A',
      duration: const Duration(minutes: 3),
      file: 't$i.m4a',
      cover: '',
      gainDb: 0,
    );

List<PlayEvent> _events() => [
      for (var i = 0; i < 6; i++)
        PlayEvent(
          trackId: 't${i % 3}',
          at: DateTime(2026, 10, 9, 21, i),
          band: i.isEven ? 'evening' : 'morning',
          positionMs: 180000,
          durationMs: 180000,
        ),
    ];

Future<void> _pump(WidgetTester tester, {required bool contextEnabled}) async {
  tester.view.physicalSize = const Size(400, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: HistoryScreen(
        skin: kSkinCrimson,
        events: _events(),
        tracks: [for (var i = 0; i < 3; i++) _t(i)],
        contextEnabled: contextEnabled,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('BY TIME OF DAY is drawn when the app is reading its situation', (tester) async {
    await _pump(tester, contextEnabled: true);
    expect(find.textContaining('BY TIME OF DAY'), findsOneWidget,
        reason: 'the band chart vanished with OFFLINE on, which is where the context reading lives');
  });

  testWidgets('and it is GONE with the offline toggle off', (tester) async {
    await _pump(tester, contextEnabled: false);
    expect(find.textContaining('BY TIME OF DAY'), findsNothing,
        reason: '"By time of day should be locked behind offline toggle" — it is still charting a context the '
            'app is not reading');

    expect(find.textContaining('TOP TRACKS'), findsOneWidget,
        reason: 'switching OFFLINE off took the whole history with it');
  });

  testWidgets('NEW OR KNOWN is not shown at all', (tester) async {
    await _pump(tester, contextEnabled: true);
    expect(find.textContaining('NEW OR KNOWN'), findsNothing,
        reason: '"New or Known should removed"');
  });
}
