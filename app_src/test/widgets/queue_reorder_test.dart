@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/swipeable_queue_row.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Track $id',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5 Royal',
      duration: const Duration(seconds: 90),
      file: '$id.m4a',
      cover: '',
      gainDb: 0,
    );

Future<List<String>> _pump(WidgetTester tester, {int count = 6}) async {
  final moves = <String>[];
  final ids = [for (var i = 0; i < count; i++) 't$i'];

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 380,
        height: 600,
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: ids.length,
          onReorderItem: (from, to) {
            if (to != from) moves.add('$from->$to');
          },
          itemBuilder: (context, i) => Padding(
            key: ValueKey(ids[i]),
            padding: const EdgeInsets.only(bottom: 10),
            child: ReorderableDelayedDragStartListener(
              index: i,
              child: SwipeableQueueRow(
                skin: kSkinCrimson,
                track: _t(ids[i]),
                isCurrent: false,
                index: i,
                upNextLength: ids.length,
                onMove: (_, __) {},
                onRemove: () {},
                onReloadAfterRemove: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return moves;
}

Future<void> _grabAndDrag(WidgetTester tester, String title, double dy) async {
  final start = tester.getCenter(find.text(title));

  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 600));

  const steps = 10;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('long-press then drag reorders', () {
    testWidgets('dragging UP one row moves it one place earlier', (tester) async {
      final moves = await _pump(tester, count: 5);
      expect(moves, isEmpty);

      await _grabAndDrag(tester, 'Track t2', -kQueueRowHeight * 1.5);

      expect(moves, isNotEmpty,
          reason: 'the long-press drag did not reorder anything');
      expect(moves.first, startsWith('2->'));
    });

    testWidgets('dragging DOWN one row moves it one place later', (tester) async {
      final moves = await _pump(tester, count: 5);

      await _grabAndDrag(tester, 'Track t1', kQueueRowHeight * 1.5);

      expect(moves, isNotEmpty);
      expect(moves.first, startsWith('1->'));
    });

    testWidgets('a nudge below half a row does NOT reorder', (tester) async {
      final moves = await _pump(tester, count: 5);

      await _grabAndDrag(tester, 'Track t2', -kQueueRowHeight * 0.2);

      expect(moves, isEmpty, reason: 'a nudge must not reorder the queue');
    });

    testWidgets('a SHORT press does not start a reorder', (tester) async {
      final moves = await _pump(tester, count: 5);

      final gesture = await tester.startGesture(
          tester.getCenter(find.text('Track t2')));
      await tester.pump(const Duration(milliseconds: 80));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, -kQueueRowHeight * 0.15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moves, isEmpty,
          reason: 'a quick swipe must scroll, not reorder');
    });

    testWidgets('it cannot be dragged off the top', (tester) async {
      final moves = await _pump(tester, count: 4);

      await _grabAndDrag(tester, 'Track t0', -kQueueRowHeight * 3);

      for (final m in moves) {
        final to = int.parse(m.split('->').last);
        expect(to, inInclusiveRange(0, 3));
      }
    });

    testWidgets('it cannot be dragged off the bottom', (tester) async {
      final moves = await _pump(tester, count: 4);

      await _grabAndDrag(tester, 'Track t3', kQueueRowHeight * 3);

      for (final m in moves) {
        final to = int.parse(m.split('->').last);
        expect(to, inInclusiveRange(0, 3));
      }
    });
  });

  group('the PLAYING row is not draggable', () {
    testWidgets('a locked row is not wrapped in a drag listener', (tester) async {
      final moves = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 380,
            height: 300,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: 1,
              onReorderItem: (from, to) => moves.add('$from->$to'),
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.zero,
                key: const ValueKey('current'),
                child: SwipeableQueueRow(
                  skin: kSkinCrimson,
                  track: _t('current'),
                  isCurrent: true,
                  index: null,
                  upNextLength: null,
                  onMove: (_, __) {},
                  onRemove: () {},
                  onReloadAfterRemove: () {},
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SwipeableQueueRow),
          matching: find.byType(ReorderableDelayedDragStartListener),
        ),
        findsNothing,
      );
      expect(moves, isEmpty);
    });
  });
}
