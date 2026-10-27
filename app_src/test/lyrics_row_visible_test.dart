@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/rules/playlist_explanation.dart';
import 'package:sonarar/screens/why_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/lyrics_view.dart';

void main() {
  testWidgets('WhyPanel renders the trailing slot with a real height',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            LyricsRow(skin: kSkinCrimson, onOpen: () {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(LyricsRow.rowKey));
    expect(rect.height, greaterThan(20),
        reason: 'the lyrics row has no height, so it cannot be seen');
    expect(rect.width, greaterThan(100));
  });

  testWidgets('THE ONE THAT MATTERS: the row is inside the panel, not below it',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const explanation = PlaylistExplanation(context: [], playing: [], excluded: []);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WhyPanel(
            state: AppState(),
            explanation: explanation,
            alternatives: const [],
            trailing: LyricsRow(skin: kSkinCrimson, onOpen: () {}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(WhyPanel));
    final row = tester.getRect(find.byKey(LyricsRow.rowKey));

    expect(row.height, greaterThan(20), reason: 'the row has no height');
    expect(row.bottom, lessThanOrEqualTo(panel.bottom + 0.5),
        reason: 'the row sits BELOW the panel painted area, so it cannot be seen');
    expect(row.top, greaterThanOrEqualTo(panel.top));
  });
}
