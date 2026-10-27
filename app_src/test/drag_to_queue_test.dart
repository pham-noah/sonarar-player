library;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart' show RepeatMode;
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _lib(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

void main() {
  testWidgets('a drag to the bar puts the track that was dragged in the queue',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState()..attachLibrary(_lib(6));

    state.setQueueForTest([_t('t0')]);

    final dropped = <String>[];
    final skin = skinFor(SkinId.crimson);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: LibraryScreen(

                searchOnly: true,
                entryToken: 0,
                tracks: _lib(6),
                coverPathFor: (_) => null,
                skin: skin,
                onDragToQueue: (t) => dropped.add(t.id),
              ),
            ),
            MiniPlayer(
              skin: skin,
              track: _t('t0'),
              cover: null,
              playing: true,
              onPlayPause: () {},
              onCycleRepeat: () {},
              repeatMode: RepeatMode.off,
              onAcceptTrack: (t) => dropped.add(t.id),
            ),
          ],
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final draggable = find.byType(LongPressDraggable<Track>).first;
    expect(draggable, findsOneWidget,
        reason: 'no row is draggable — the gesture is not wired to the rows');

    final target = find.byType(MiniPlayer);
    expect(target, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(draggable));

    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, isNotEmpty,
        reason: 'the drop never arrived — a drag that lands nowhere teaches the wrong gesture');
  });

  testWidgets('THE GRID ARRANGEMENT is draggable too — the regression that shipped',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState()..attachLibrary(_lib(6));
    state.setQueueForTest([_t('t0')]);

    final dropped = <String>[];
    final skin = skinFor(SkinId.crimson);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: LibraryScreen(
                searchOnly: true,
                entryToken: 0,
                tracks: _lib(6),
                coverPathFor: (_) => null,
                skin: skin,

                grid: true,
                onDragToQueue: (t) => dropped.add(t.id),
                onManage: (_) {},
              ),
            ),
            MiniPlayer(
              skin: skin,
              track: _t('t0'),
              cover: null,
              playing: true,
              onPlayPause: () {},
              onCycleRepeat: () {},
              repeatMode: RepeatMode.off,
              onAcceptTrack: (t) => dropped.add(t.id),
            ),
          ],
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final draggable = find.byType(LongPressDraggable<Track>).first;
    expect(draggable, findsOneWidget,
        reason: 'the GRID has no draggable — Solid and Glass default to this arrangement, '
            'so dragging a song does nothing there');

    final gesture = await tester.startGesture(tester.getCenter(draggable));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(find.byType(MiniPlayer)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dropped, isNotEmpty,
        reason: 'the drop from the GRID never arrived');
  });

  testWidgets('with no queue there is nothing to drop on to', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MiniPlayer(
          skin: skinFor(SkinId.crimson),
          track: _t('t0'),
          cover: null,
          playing: true,
          onPlayPause: () {},
          onCycleRepeat: () {},
          repeatMode: RepeatMode.off,

        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(DragTarget<Track>), findsNothing,
        reason: 'the bar offers a drop target with nowhere for the drop to go');
  });
}
