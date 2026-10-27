@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/lyrics.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/lyrics_view.dart';

Lyrics _sheet() => Lyrics(
      lines: [
        for (var i = 0; i < 10; i++)
          LyricLine(Duration(seconds: i), 'line number $i'),
      ],
      source: 'test',
    );

Widget _host({
  required Duration at,
  required ScrollController controller,
}) =>
    MaterialApp(
      home: LyricsView(
        skin: kSkinCrimson,
        lyrics: _sheet(),
        position: at,
        controller: controller,
        onExit: () {},
      ),
    );

void main() {
  testWidgets('a drag moves the list, and NOTHING drags it back', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 3),
      controller: controller,
    ));
    await tester.pumpAndSettle();
    final followed = controller.offset;

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    final browsed = controller.offset;
    expect(browsed, isNot(closeTo(followed, 1.0)),
        reason: 'the drag did not move the list at all');

    await tester.pumpWidget(_host(
      at: const Duration(seconds: 6),
      controller: controller,
    ));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(browsed, 1.0),
        reason: 'the song pulled the view back, so scrolling is not free');

    expect(find.byKey(const Key('lyrics-sync')), findsOneWidget,
        reason: 'no way back to the song after scrolling away');
  });

  testWidgets('SYNC puts the viewport back on the sung line', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 3),
      controller: controller,
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lyrics-sync')));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(3 * kLyricSlot, 1.0),
        reason: 'SYNC did not return the view to the current line');

    expect(find.byKey(const Key('lyrics-sync')), findsNothing,
        reason: 'the sync button stayed after syncing');
  });

  testWidgets('SYNC works even before the first timed line', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 0),
      controller: controller,
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lyrics-sync')), findsOneWidget);

    await tester.tap(find.byKey(const Key('lyrics-sync')));
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(0, 1.0),
        reason: 'SYNC did nothing before the first timed line');
  });

  testWidgets('there is no sync control until the reader has moved', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 3),
      controller: controller,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lyrics-sync')), findsNothing,
        reason: 'a sync button with nothing to sync is a dead control');
  });

  testWidgets('tapping a LINE moves the TIMELINE and recenters', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final sought = <Duration>[];
    await tester.pumpWidget(MaterialApp(
      home: LyricsView(
        skin: kSkinCrimson,
        lyrics: _sheet(),
        position: const Duration(seconds: 3),
        controller: controller,
        onExit: () {},
        onSeek: sought.add,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('line number 7'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('line number 7'));
    await tester.pumpAndSettle();

    expect(sought, [const Duration(seconds: 7)],
        reason: 'tapping a line did not move the timeline to it');
    expect(controller.offset, closeTo(7 * kLyricSlot, 1.0),
        reason: 'the view did not recenter on the line that was pressed');
  });

  testWidgets('there is always a way out of the mode', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(
      at: const Duration(seconds: 3),
      controller: controller,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lyrics-exit')), findsOneWidget,
        reason: 'no way back to the player from lyrics mode');
  });
}
