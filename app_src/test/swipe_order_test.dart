@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/swipe_panel.dart';

Track _t() => Track(
      id: 'a', title: 'Rivers In the Desert', artist: 'ATLUS Sound Team',
      album: 'P5', duration: const Duration(minutes: 4), file: 'a.opus',
      cover: '', gainDb: null,
    );

void main() {
  testWidgets('the SwipePanel is painted BEFORE the row, so the row covers it',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: LibraryScreen(
          tracks: [_t()],
          coverPathFor: (_) => null,
          skin: kSkinCrimson,

          searchOnly: true,

          onQueue: (_) => SwipeOutcome.queued,
          onLike: (_) => SwipeOutcome.liked,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final centre = tester.getCenter(find.text('Rivers In the Desert'));
    final gesture = await tester.startGesture(centre);
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await tester.pump();

    final panels = find.byType(SwipePanel);
    final row = find.text('Rivers In the Desert');

    expect(panels, findsOneWidget,
        reason: 'expected exactly ONE panel, on the side being swiped');
    expect(row, findsOneWidget);

    final inside = find
        .descendant(
          of: find.byKey(kLibraryRowSlideKey),
          matching: find.byType(SwipePanel),
        )
        .evaluate();
    expect(inside, isEmpty,
        reason: 'the panel is inside the slide transform, so it moves with the row');
  });
}
