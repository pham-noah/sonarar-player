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
    ];

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'p3r', name: 'P3R', trackIds: ['a']),
      Playlist(id: 'pl_9', name: 'Mine', trackIds: ['a']),
    ]);

Future<void> _pump(WidgetTester tester) async {
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
        onPlay: (_) {},
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        onPlayPlaylist: (_) {},
      ),
    ),
  ));
  await tester.pump();
}

Future<void> _tapPlaylists(WidgetTester tester) async {
  await tester.tap(find.text('PLAYLISTS'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on arrival: three views, no kind choices, no X', (tester) async {
    await _pump(tester);
    expect(find.text('PLAYLISTS'), findsOneWidget);
    expect(find.text('ARTISTS'), findsOneWidget);
    expect(find.text('SONGS'), findsOneWidget);

    expect(find.text('SEEDED'), findsNothing,
        reason: 'SEEDED is offered on arrival — "there will no default filter on"');
    expect(find.text('CUSTOM'), findsNothing,
        reason: 'CUSTOM is offered on arrival');
  });

  testWidgets('PRESSING PLAYLISTS ITSELF collapses the row and shows the X', (tester) async {
    await _pump(tester);
    await _tapPlaylists(tester);

    expect(find.text('ARTISTS'), findsNothing,
        reason: 'pressing PLAYLISTS must make ARTISTS disappear — "others will disappear"');
    expect(find.text('SONGS'), findsNothing,
        reason: 'pressing PLAYLISTS must make SONGS disappear');

    expect(find.byIcon(Icons.close_rounded), findsOneWidget,
        reason: 'the X must appear the moment PLAYLISTS is pressed — "there will be new x button at the '
            'most left"');

    expect(find.text('SEEDED'), findsOneWidget,
        reason: 'pressing PLAYLISTS should offer the kinds — "it will appear next to it for you to choose"');
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text('PLAYLISTS'), findsOneWidget);
  });

  testWidgets('CHOOSING a kind collapses the row: others gone, the chosen one stuck on',
      (tester) async {
    await _pump(tester);
    await _tapPlaylists(tester);
    expect(find.text('SEEDED'), findsOneWidget, reason: 'precondition: the choices are showing');

    await tester.tap(find.text('SEEDED'));
    await tester.pumpAndSettle();

    expect(find.text('ARTISTS'), findsNothing,
        reason: 'ARTISTS must disappear once a filter is chosen — '
            '"others will disappear"');
    expect(find.text('SONGS'), findsNothing,
        reason: 'SONGS must disappear once a filter is chosen');

    expect(find.byIcon(Icons.close_rounded), findsOneWidget,
        reason: 'there must be an X at the most left once a filter is chosen — '
            '"there will be new x button at the most left"');

    expect(find.text('SEEDED'), findsOneWidget,
        reason: 'the chosen kind stays on screen — "it will stuck to the father of that"');
    expect(find.text('PLAYLISTS'), findsOneWidget,
        reason: 'PLAYLISTS stays, being the thing the filter is a filter OF');
  });

  testWidgets('PRESSING PLAYLISTS A SECOND TIME toggles the filter back off', (tester) async {
    await _pump(tester);
    await _tapPlaylists(tester);
    expect(find.text('ARTISTS'), findsNothing, reason: 'precondition: the first press collapsed the row');

    await _tapPlaylists(tester);

    expect(find.text('ARTISTS'), findsOneWidget,
        reason: 'pressing PLAYLISTS again must bring ARTISTS back — it does not toggle off');
    expect(find.text('SONGS'), findsOneWidget,
        reason: 'pressing PLAYLISTS again must bring SONGS back');
    expect(find.byIcon(Icons.close_rounded), findsNothing,
        reason: 'the X must go away when the filter is off');
    expect(find.text('SEEDED'), findsNothing,
        reason: 'the kind choices must close with it');
  });

  testWidgets('a trip to ARTISTS and back is survivable, and Playlists responds', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('ARTISTS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'switching to ARTISTS threw');

    expect(find.text('PLAYLISTS'), findsOneWidget,
        reason: 'switching to ARTISTS collapsed the bar; collapsing belongs to PLAYLISTS alone');
    expect(find.text('SONGS'), findsOneWidget,
        reason: 'the other views must still be reachable from ARTISTS');

    await _tapPlaylists(tester);
    expect(tester.takeException(), isNull, reason: 'returning to PLAYLISTS threw');
    expect(find.text('PLAYLISTS'), findsOneWidget);
  });

  testWidgets('PLAYLISTS can be UNCHOSEN — its choices fold away on the second press', (tester) async {
    await _pump(tester);

    await _tapPlaylists(tester);
    expect(find.text('SEEDED'), findsOneWidget,
        reason: 'pressing PLAYLISTS should open its kinds');

    await _tapPlaylists(tester);
    expect(find.text('SEEDED'), findsNothing,
        reason: 'PLAYLISTS is still painted as chosen after being turned off — '
            '"cannot be unchosen"');
  });

  testWidgets('the X clears the filter and brings the other views back', (tester) async {
    await _pump(tester);
    await _tapPlaylists(tester);
    await tester.tap(find.text('SEEDED'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('ARTISTS'), findsOneWidget,
        reason: '"others will be appeared again"');
    expect(find.text('SONGS'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing,
        reason: 'the X is gone once nothing is filtered');
  });
}
