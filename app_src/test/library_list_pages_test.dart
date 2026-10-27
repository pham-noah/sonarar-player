library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_browser.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'A',
      duration: const Duration(seconds: 90),
      file: '$id.m4a',
      cover: '',
      gainDb: 0,
    );

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'jpop', name: 'JPOP', trackIds: const ['a', 'b']),
    ]);

void main() {
  late List<Playlist> added;

  Future<void> pump(WidgetTester tester) async {
    added = <Playlist>[];
    tester.view.physicalSize = const Size(400, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: LibraryScreen(
          tracks: [_t('a'), _t('b')],
          coverPathFor: (_) => null,
          skin: kSkinCrimson,
          playlists: _lists(),
          pinnedPlaylistIds: const [],
          onPlay: (_) {},
          onCreatePlaylist: (_) {},
          onDeletePlaylist: (_) {},
          onPlayPlaylist: (_) {},

          onAddSongsTo: (p) => added.add(p),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('at the top of the library the browser bar is drawn', (tester) async {
    await pump(tester);
    expect(find.byType(LibraryBrowserBar), findsOneWidget,
        reason: 'the bar is how the library itself is browsed, which is where he is standing');
  });

  testWidgets('opening a playlist takes the bar away', (tester) async {
    await pump(tester);
    await tester.tap(find.text('JPOP'));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryBrowserBar), findsNothing,
        reason: '"when press artist or a playlist. The filter playlist artist song should be removed in that."');
  });

  testWidgets('and the `+` inside it adds songs TO THAT playlist', (tester) async {
    await pump(tester);
    await tester.tap(find.text('JPOP'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget,
        reason: 'the + inside a playlist is still the bare new-playlist plus');
    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pump();

    expect(added.map((p) => p.id), ['jpop'],
        reason: 'the + did not hand the OPEN playlist to the add callback, so there is nothing to add to');
  });

  testWidgets('the top-of-library `+` still makes a playlist', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget,
        reason: 'with no list open the + must still be the new-playlist control');
    expect(find.byIcon(Icons.playlist_add_rounded), findsNothing);
  });
}
