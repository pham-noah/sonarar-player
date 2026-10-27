library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks() => [
      Track(id: 'a', title: 'Alpha', artist: 'A', album: 'P3R',
          duration: const Duration(seconds: 90), file: 'a.m4a', cover: '', gainDb: 0),
      Track(id: 'b', title: 'Beta', artist: 'B', album: 'P3R',
          duration: const Duration(seconds: 90), file: 'b.m4a', cover: '', gainDb: 0),
    ];

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'p3r', name: 'P3R', trackIds: ['a', 'b']),
      Playlist(id: 'pl_1', name: 'Mine', trackIds: ['a']),
    ]);

Future<void> _pump(WidgetTester tester, {required bool grid}) async {
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
        playlistGrid: grid,
        onPlay: (_) {},
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        onPlayPlaylist: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('in grid mode the cell is about a third of the width', (tester) async {
    await _pump(tester, grid: true);

    final cell = tester.getSize(
      find.ancestor(
        of: find.text('P3R'),
        matching: find.byType(SizedBox),
      ).first,
    );
    final content = tester.getSize(find.byType(LibraryScreen)).width - 40;
    const gap = 12.0;
    final expected = (content - gap * 2) / 3;

    expect(cell.width, closeTo(expected, 0.5),
        reason: 'a grid cell is ${cell.width}pt wide, not the ${expected}pt three columns imply. Either the '
            'column count is not three, or the padding/gap moved and the arithmetic was not updated with it.');
  });

  testWidgets('Liked Songs IS a grid cell, not a full-width row above it', (tester) async {
    await _pump(tester, grid: true);

    final liked = find.text('Liked Songs');
    expect(liked, findsOneWidget,
        reason: 'Liked Songs is not in the grid at all — this is bug 2: the fixed lists were left OUTSIDE the '
            'grid, drawn as full-width rows above it');

    final cell = tester.getSize(
      find.ancestor(of: liked, matching: find.byType(SizedBox)).first,
    );
    final fullWidth = tester.getSize(find.byType(LibraryScreen)).width;

    expect(cell.width, lessThan(fullWidth / 2),
        reason: 'Liked Songs is ${cell.width}pt wide on a ${fullWidth}pt screen — that is a full-width ROW, '
            'not a cell in a three-column grid');
  });
}
