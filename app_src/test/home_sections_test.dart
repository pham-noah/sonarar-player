library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/home_screen.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(int i) => Track(
      id: 't$i',
      title: 'Title $i',
      artist: 'Artist $i',
      album: 'A',
      duration: const Duration(seconds: 90),
      file: 't$i.m4a',
      cover: '',
      gainDb: 0,
    );

Future<void> _pump(
  WidgetTester tester, {
  List<Track> mostPlayed = const [],
  List<Track> liked = const [],
  Playlist? recent,
  List<Track> recap = const [],
  List<Playlist> genre = const [],
  List<({Playlist playlist, int plays})> library = const [],
  VoidCallback? onOpenRecap,
}) async {
  tester.view.physicalSize = const Size(400, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: HomeScreen(
        skin: kSkinCrimson,
        band: 'afternoon',
        greeting: 'Good afternoon',
        mostPlayed: mostPlayed,
        likedSongs: liked,
        recentPlaylist: recent,
        genreLists: genre,
        libraryPlaylists: library,
        recapTracks: recap,
        recapLabel: 'THIS MONTH',
        allTracks: [for (var i = 0; i < 40; i++) _t(i)],
        onPlay: (_) {},
        onOpenRecap: onOpenRecap ?? () {},
        onOpenRecentPlaylist: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('there is no tab strip — Home is one page', (tester) async {
    await _pump(tester);

    expect(find.byType(PageView), findsNothing,
        reason: 'Home is paging again — "it should layout in just one page not multiple pages"');
  });

  testWidgets('QUICK PICK is four ROWS, not a grid of tiles', (tester) async {
    await _pump(tester, mostPlayed: [for (var i = 0; i < 12; i++) _t(i)]);
    expect(find.textContaining('QUICK PICK'), findsOneWidget,
        reason: 'the Quick Pick section is missing from the page');

    expect(find.byType(GridView), findsNothing,
        reason: 'Quick Pick is drawing a GRID — "quickpick is not a grid"');
  });

  testWidgets('GENRE is hidden, and the playlists are a row that swipes under FROM YOUR LIBRARY',
      (tester) async {
    await _pump(
      tester,
      library: [
        (playlist: Playlist(id: 'pl_1', name: 'JPOP', trackIds: const ['t1']), plays: 30),
        (playlist: Playlist(id: 'pl_2', name: 'VPOP', trackIds: const ['t2']), plays: 4),
      ],
    );

    expect(find.text('GENRE'), findsNothing,
        reason: '"1. hide genre" — the section is still drawn');
    expect(find.textContaining('FROM YOUR LIBRARY'), findsOneWidget,
        reason: 'the library playlist row is missing from the page');
    expect(find.text('JPOP'), findsOneWidget,
        reason: 'his playlist is not drawn as a FROM YOUR LIBRARY cell');

    final row = tester.widget<ListView>(
      find.ancestor(of: find.text('JPOP'), matching: find.byType(ListView)).first,
    );
    expect(row.scrollDirection, Axis.horizontal,
        reason: 'the playlists are not in a side-swiped row');
  });

  testWidgets('and the row draws the RANKING it is given, most played first', (tester) async {
    await _pump(
      tester,
      library: [
        (playlist: Playlist(id: 'pl_1', name: 'Loud', trackIds: const ['t1']), plays: 90),
        (playlist: Playlist(id: 'pl_2', name: 'Quiet', trackIds: const ['t2']), plays: 3),
      ],
    );
    final loud = tester.getTopLeft(find.text('Loud')).dx;
    final quiet = tester.getTopLeft(find.text('Quiet')).dx;
    expect(loud, lessThan(quiet),
        reason: 'the most-played playlist must be the first tile in the row');

    expect(find.textContaining('90 plays'), findsOneWidget,
        reason: 'the tile does not say how much it has been played, so the ranking is invisible');
  });

  testWidgets('RECAP is a playlist card naming the month', (tester) async {
    await _pump(tester, recap: [for (var i = 0; i < 6; i++) _t(i)]);
    expect(find.textContaining('RECAP'), findsWidgets,
        reason: '"2. recap should be a playlist" — the recap section is missing');

    expect(find.textContaining('you played'), findsOneWidget,
        reason: 'RECAP is not drawing as a playlist card with its song count');
  });

  testWidgets('and pressing the RECAP card GOES somewhere', (tester) async {
    var opened = 0;
    await _pump(tester, recap: [for (var i = 0; i < 3; i++) _t(i)], onOpenRecap: () => opened++);

    await tester.tap(find.textContaining('you played'));
    await tester.pump();

    expect(opened, 1, reason: 'the RECAP card was pressed and nothing was called — the press goes nowhere');
  });

  testWidgets('TRENDING is gone, not explained', (tester) async {
    await _pump(tester);

    expect(find.text('TRENDING'), findsNothing,
        reason: 'a section with no source is noise on a front page');
    expect(find.textContaining('not connected'), findsNothing);
  });

  testWidgets('an empty library shows the rails, not a stand-in for them', (tester) async {
    await _pump(tester);

    expect(find.text('ALL MUSIC'), findsNothing,
        reason: 'a library dump under a heading is not what a front page is for');
    expect(find.text('NOTHING HERE YET'), findsNothing);
  });

  testWidgets('nothing on Home renders below the 16px floor', (tester) async {
    await _pump(tester, mostPlayed: [for (var i = 0; i < 6; i++) _t(i)]);

    final small = <String>[];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final size = text.style?.fontSize;
      if (size != null && size < 16) small.add('${text.data} @ $size');
    }
    expect(small, isEmpty, reason: 'below the floor: $small');
  });
}
