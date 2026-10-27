library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks() => [
      for (var i = 0; i < 4; i++)
        Track(
          id: 't$i',
          title: 'Track $i',
          artist: 'Artist ${i % 2}',
          album: 'P3R',
          duration: const Duration(seconds: 90),
          file: 't$i.m4a',
          cover: '',
          gainDb: 0,
        ),
    ];

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'p3r', name: 'P3R', trackIds: const ['t0', 't1']),
    ]);

Future<_Harness> _pump(WidgetTester tester) async {
  final harness = _Harness();
  tester.view.physicalSize = const Size(400, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: LibraryScreen(
        tracks: _tracks(),
        coverPathFor: (_) => null,
        skin: kSkinCrimson,
        playlists: _lists(),
        closeListRequest: harness.request,
        onListOpenChanged: harness.reports.add,
        onPlay: (_) {},
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        onPlayPlaylist: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return harness;
}

class _Harness {
  final List<bool> reports = [];
  int request = 0;
}

void main() {
  testWidgets('opening a list REPORTS it, so the shell can decide what back means',
      (tester) async {
    final h = await _pump(tester);
    expect(h.reports, isEmpty, reason: 'a report was sent before anything was opened');

    await tester.tap(find.text('P3R'));
    await tester.pumpAndSettle();

    expect(h.reports, [true],
        reason: 'opening a playlist did not tell the shell. Without this the shell sees an ordinary Library '
            'tab, finds nothing to undo, and CLOSES THE APP on a back press — the bug the phone found');
  });

  testWidgets('a close REQUEST closes the list and reports it closed', (tester) async {
    final h = await _pump(tester);

    await tester.tap(find.text('P3R'));
    await tester.pumpAndSettle();
    // ignore: avoid_dynamic_calls
    final state = tester.state(find.byType(LibraryScreen)) as dynamic;
    expect(state.debugListOpen, isTrue, reason: 'the list never opened, so the close proves nothing');

    h.request++;
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: LibraryScreen(
          tracks: _tracks(),
          coverPathFor: (_) => null,
          skin: kSkinCrimson,
          playlists: _lists(),
          closeListRequest: h.request,
          onListOpenChanged: h.reports.add,
          onPlay: (_) {},
          onCreatePlaylist: (_) {},
          onDeletePlaylist: (_) {},
          onPlayPlaylist: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(state.debugListOpen, isFalse,
        reason: 'the close request did not close the list — a back press would leave it open');
    expect(h.reports.last, isFalse,
        reason: 'the list closed but the shell was not told, so the NEXT back press would close the app');
  });
}
