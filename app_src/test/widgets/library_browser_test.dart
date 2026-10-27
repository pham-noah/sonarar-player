@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_browser.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks() => [
      Track(id: 'a', title: 'Alpha', artist: 'Lotus Juice', album: 'P3R',
          duration: const Duration(seconds: 90), file: 'a.m4a', cover: '', gainDb: 0),
      Track(id: 'b', title: 'Beta', artist: 'ATLUS Sound Team', album: 'P3R',
          duration: const Duration(seconds: 90), file: 'b.m4a', cover: '', gainDb: 0),
      Track(id: 'c', title: 'Gamma', artist: 'Lotus Juice', album: 'P3R',
          duration: const Duration(seconds: 90), file: 'c.m4a', cover: '', gainDb: 0),
    ];

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'p3r', name: 'P3R', trackIds: ['c', 'a', 'b']),
    ]);

Future<void> _pump(WidgetTester tester, {PlaylistList? lists}) async {
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: LibraryScreen(
        tracks: _tracks(),
        coverPathFor: (_) => null,
        skin: kSkinCrimson,
        playlists: lists ?? _lists(),
        onPlay: (_) {},
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        onPlayPlaylist: (_) {},
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('the three views', () {
    testWidgets('it opens on PLAYLISTS — collections, not every track',
        (tester) async {
      await _pump(tester);
      expect(find.text('PLAYLISTS'), findsOneWidget);
      expect(find.text('ARTISTS'), findsOneWidget);
      expect(find.text('SONGS'), findsOneWidget,
          reason: 'Songs is an axis of the Library again — the full list lives here');

      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('PLAYLISTS shows the playlists and a way to make one',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pump();

      expect(find.text('P3R'), findsOneWidget);

      expect(find.text('NEW PLAYLIST'), findsNothing,
          reason: 'the old full-width button is still being drawn');

      expect(find.byIcon(Icons.add_rounded), findsWidgets,
          reason: 'there must still be a way to make a playlist');

      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('ARTISTS groups by artist, not by track', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('ARTISTS'));
      await tester.pump();

      expect(find.text('Lotus Juice'), findsOneWidget);
      expect(find.text('ATLUS Sound Team'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('the browser bar shows the three VIEWS and no counts', (tester) async {
      await _pump(tester);
      expect(find.text('PLAYLISTS'), findsOneWidget);
      expect(find.text('ARTISTS'), findsOneWidget);
      expect(find.text('SONGS'), findsOneWidget);
      expect(find.text('1'), findsNothing,
          reason: 'a count is still being drawn on a segment');
      expect(find.text('2'), findsNothing,
          reason: 'a count is still being drawn on a segment');
    });
  });

  group('opening a playlist', () {
    testWidgets('shows its tracks IN THE PLAYLIST\'S ORDER', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pump();
      await tester.tap(find.text('P3R'));
      await tester.pump();
      await tester.pump();

      final yAlpha = tester.getTopLeft(find.text('Alpha')).dy;
      final yBeta = tester.getTopLeft(find.text('Beta')).dy;
      final yGamma = tester.getTopLeft(find.text('Gamma')).dy;

      expect(yGamma, lessThan(yAlpha), reason: 'Gamma is first in the playlist');
      expect(yAlpha, lessThan(yBeta), reason: 'Alpha is before Beta');
    });

    testWidgets('there is a way back to the library', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pump();
      await tester.tap(find.text('P3R'));
      await tester.pump();
      await tester.pump();

      final back = find.byIcon(Icons.arrow_back_rounded);
      expect(back, findsOneWidget);

      await tester.tap(back);
      await tester.pump();
      await tester.pump();

      expect(find.text('P3R'), findsOneWidget,
          reason: 'the back arrow should return to the playlist list');
    });
  });

  group('opening an artist', () {
    testWidgets('shows only that artist\'s tracks', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('ARTISTS'));
      await tester.pump();
      await tester.tap(find.text('Lotus Juice'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);

      expect(find.text('Beta'), findsNothing);
    });
  });

  group('grouping is derived, never stored', () {
    test('groupByArtist groups in library order within each artist', () {
      final g = groupByArtist(_tracks());
      expect(g.keys.toSet(), {'Lotus Juice', 'ATLUS Sound Team'});
      expect(g['Lotus Juice']!.map((t) => t.id), ['a', 'c']);
      expect(g['ATLUS Sound Team']!.map((t) => t.id), ['b']);
    });

    test('a track with a blank artist is left out rather than grouped as ""', () {
      final g = groupByArtist([
        ..._tracks(),
        Track(id: 'z', title: 'Zed', artist: '  ', album: 'x',
            duration: const Duration(seconds: 1), file: 'z.m4a', cover: '', gainDb: 0),
      ]);
      expect(g.containsKey(''), isFalse);
      expect(g.containsKey('  '), isFalse);
    });
  });
}
