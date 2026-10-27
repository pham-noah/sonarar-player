@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/swipeable_queue_row.dart';

Track _t(String id) => Track(
      id: id,
      title: 'A very long track title that will not fit on one line at all',
      artist: 'ATLUS Sound Team',
      album: 'Persona 3 Reload',
      duration: const Duration(seconds: 180),
      file: '$id.m4a',
      cover: '',
      gainDb: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool isCurrent,
  int? index = 1,
  int? upNextLength = 4,
  void Function(int, int)? onMove,
  VoidCallback? onRemove,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: SwipeableQueueRow(
            skin: kSkinAbyss,
            track: _t('t1'),
            isCurrent: isCurrent,
            index: isCurrent ? null : index,
            upNextLength: isCurrent ? null : upNextLength,
            onMove: onMove ?? (_, __) {},
            onRemove: onRemove ?? () {},
            onReloadAfterRemove: () {},
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

double _dx(WidgetTester tester) {
  final dynamic state = tester.state(find.byType(SwipeableQueueRow));
  // ignore: avoid_dynamic_calls
  return state.horizontalOffset as double;
}

Future<void> dragBy(WidgetTester tester, Offset total, {int steps = 8}) async {
  final g = await tester.startGesture(
      tester.getCenter(find.byType(SwipeableQueueRow)));

  await g.moveBy(Offset(total.dx.sign * 20, total.dy.sign * 20));
  await tester.pump();
  final step = Offset(total.dx / steps, total.dy / steps);
  for (var i = 0; i < steps; i++) {
    await g.moveBy(step);
    await tester.pump();
  }
  await g.up();
  await tester.pump();
}

void main() {
  group('swipe left FOLLOWS the finger', () {
    testWidgets('the row moves while the drag is in progress', (tester) async {
      await _pump(tester, isCurrent: false);
      expect(_dx(tester), 0);

      final g = await tester.startGesture(tester.getCenter(find.byType(SwipeableQueueRow)));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
      await g.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(_dx(tester), lessThan(-40),
          reason: 'row did not follow the finger — gesture is invisible');
      await g.up();
      await tester.pump();
    });

    testWidgets('a short swipe springs BACK and removes nothing', (tester) async {
      var removed = false;
      await _pump(tester, isCurrent: false, onRemove: () => removed = true);

      final g = await tester.startGesture(tester.getCenter(find.byType(SwipeableQueueRow)));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
      await g.up();
      await tester.pump();

      expect(removed, isFalse, reason: 'a small drift must not delete a track');
      expect(_dx(tester), 0, reason: 'row must return, not stay displaced');
    });

    testWidgets('a long swipe past the threshold removes', (tester) async {
      var removed = false;
      await _pump(tester, isCurrent: false, onRemove: () => removed = true);

      final g = await tester.startGesture(tester.getCenter(find.byType(SwipeableQueueRow)));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
      await g.moveBy(const Offset(-kRemoveThreshold - 30, 0));
      await tester.pump();
      await g.up();
      await tester.pump();
      expect(removed, isTrue);
    });

    testWidgets('it never moves RIGHT — that is not a gesture here', (tester) async {
      await _pump(tester, isCurrent: false);
      final g = await tester.startGesture(tester.getCenter(find.byType(SwipeableQueueRow)));
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.moveBy(const Offset(80, 0));
      await tester.pump();
      expect(_dx(tester), 0, reason: 'rightward drag must not displace the row');
      await g.up();
      await tester.pump();
    });
  });

  group('the PLAYING track is locked', () {
    testWidgets('it cannot be swiped away', (tester) async {
      var removed = false;
      await _pump(tester, isCurrent: true, onRemove: () => removed = true);

      final g = await tester.startGesture(tester.getCenter(find.byType(SwipeableQueueRow)));
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
      await g.moveBy(const Offset(-200, 0));
      await tester.pump();

      expect(_dx(tester), 0);
      await g.up();
      await tester.pump();
      expect(removed, isFalse);
    });
  });

  group('the title does not wrap', () {
    testWidgets('a long title stays on ONE line, ellipsised', (tester) async {
      await _pump(tester, isCurrent: false);
      final titles = tester.widgetList<Text>(find.byType(Text));
      final title = titles.firstWhere((t) => (t.data ?? '').startsWith('A very long'));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
    });
  });
}
