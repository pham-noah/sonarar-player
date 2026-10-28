library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  Widget host(ValueNotifier<Duration> pos, ValueNotifier<Duration?> dur) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: PlayerProgressBar(
                skin: kSkinAbyss,
                skew: 0,
                position: pos,
                duration: dur,
                onSeek: (to) => pos.value = to,
              ),
            ),
          ),
        ),
      );

  testWidgets('a TAP seeks and then follows the track, it does not pin the bar',
      (tester) async {
    final pos = ValueNotifier<Duration>(Duration.zero);
    final dur = ValueNotifier<Duration?>(const Duration(seconds: 200));
    addTearDown(pos.dispose);
    addTearDown(dur.dispose);

    await tester.pumpWidget(host(pos, dur));

    final rect = tester.getRect(find.byType(PlayerProgressBar));
    await tester.tapAt(Offset(rect.left + 100, rect.center.dy));
    await tester.pumpAndSettle();
    expect(pos.value, const Duration(seconds: 100));

    // Playback moves on. Before the fix the fill stayed frozen at the tap.
    pos.value = const Duration(seconds: 50);
    await tester.pumpAndSettle();

    final fill = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fill.widthFactor, closeTo(0.25, 0.01));
  });

  testWidgets('a DRAG holds the bar under the finger until it ends',
      (tester) async {
    final pos = ValueNotifier<Duration>(Duration.zero);
    final dur = ValueNotifier<Duration?>(const Duration(seconds: 200));
    addTearDown(pos.dispose);
    addTearDown(dur.dispose);

    await tester.pumpWidget(host(pos, dur));

    final rect = tester.getRect(find.byType(PlayerProgressBar));
    final gesture = await tester.startGesture(
      Offset(rect.left + 40, rect.center.dy),
    );
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    pos.value = const Duration(seconds: 10);
    await tester.pump();

    final dragged = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(dragged.widthFactor, greaterThan(0.4),
        reason: 'the finger wins while the drag is live');

    await gesture.up();
    await tester.pumpAndSettle();
    final released = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(released.widthFactor, closeTo(0.05, 0.01));
  });
}
