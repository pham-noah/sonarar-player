@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/widgets/track_actions.dart';

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

// ignore: avoid_print
void _report(WidgetTester tester, String label, Finder f) {
  if (f.evaluate().isEmpty) {
    // ignore: avoid_print
    print('BUDGET $label  ABSENT');
    return;
  }
  final r = tester.getRect(f.first);
  // ignore: avoid_print
  print('BUDGET $label  top=${r.top.toStringAsFixed(1)} '
      'h=${r.height.toStringAsFixed(1)} '
      'w=${r.width.toStringAsFixed(1)} '
      'bottom=${r.bottom.toStringAsFixed(1)}');
}

void main() {
  testWidgets('BUDGET: the player control block at 360dp', (tester) async {
    final state = AppState();
    state.attachLibrary([_t('a')]);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerScreen(
            state: state,
            track: _t('a'),
            onPlayPause: () {},
            onSeek: (_) {},
            onVolume: (_) {},
            onCycleRepeat: () {},
            hasWhy: true,
            hasQueue: true,
            hasTrackPanel: true,
            upNextCount: 4,
          ),
        ),
      ),
    );
    await tester.pump();

    _report(tester, 'transport', find.byKey(PlayerScreen.transportKey));

    _report(tester, 'actions', find.byType(TrackActions));

    _report(tester, 'upNext', find.text('END OF QUEUE'));

    await tester.pumpAndSettle();
    final transport = tester.getRect(find.byKey(PlayerScreen.transportKey));
    expect(transport.width, lessThan(300),
        reason: 'the transport row is filling the width again, so FittedBox is scaling it again');
    expect(transport.height, lessThan(58),
        reason: 'the transport buttons have grown back');

    final actions = tester.getRect(find.byType(TrackActions));
    expect(actions.height, lessThan(38),
        reason: 'the action row has grown back');
  });
}
