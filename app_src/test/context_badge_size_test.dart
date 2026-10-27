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
  testWidgets('the context badge, measured', (tester) async {
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
            placeName: 'University',
            placeIcon: Icons.school_rounded,
          ),
        ),
      ),
    );
    await tester.pump();

    final badge = find.byKey(PlayerScreen.contextBadgeKey);
    expect(badge, findsOneWidget);
    final size = tester.getSize(badge);
    // ignore: avoid_print
    print('BADGE: ${size.width} x ${size.height}'
        '  (${(size.height / 800 * 100).toStringAsFixed(1)}% of a 360x800 phone)');

    expect(size.width, lessThanOrEqualTo(260),
        reason: 'the badge is eating the screen width again');
    expect(size.height, lessThanOrEqualTo(66),
        reason: 'the badge is carrying padding instead of content again');
  });
}
