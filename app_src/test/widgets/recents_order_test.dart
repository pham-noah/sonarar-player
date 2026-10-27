library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_browser.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

List<Track> _tracks() => [
      Track(id: 'a', title: 'Alpha', artist: 'A', album: 'X',
          duration: const Duration(seconds: 90), file: 'a.m4a', cover: '', gainDb: 0),
    ];

PlaylistList _lists() => PlaylistList([
      Playlist(id: 'zz', name: 'Aaa Opened Last', trackIds: const ['a']),
      Playlist(id: 'mm', name: 'Bbb Opened Middle', trackIds: const ['a']),
      Playlist(id: 'aa', name: 'Ccc Opened First', trackIds: const ['a']),
    ]);

List<String> _renderedOrder(WidgetTester tester) {
  final names = <String>[];
  for (final e in find.byType(PlaylistRow).evaluate()) {
    // ignore: avoid_dynamic_calls
    final n = (e.widget as dynamic).playlist.name as String;
    if (n == 'Liked Songs') continue;
    names.add(n);
  }
  return names;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<String> recents,
  String sort = 'recents',
  PlaylistList? lists,
  PlaylistList? mixed,
}) async {
  tester.view.physicalSize = const Size(400, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: LibraryScreen(
        tracks: _tracks(),
        coverPathFor: (_) => null,
        skin: kSkinCrimson,
        playlists: lists ?? mixed ?? _lists(),
        playlistSort: sort,

        recentPlaylistIds: recents,

        pinnedPlaylistIds: const [],
        onPlay: (_) {},
        onCreatePlaylist: (_) {},
        onDeletePlaylist: (_) {},
        onPlayPlaylist: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

PlaylistList _mixed() => PlaylistList([
      Playlist(id: 'seed_a', name: 'Seed A', trackIds: const ['a']),
      Playlist(id: 'pl_b', name: 'Custom B', trackIds: const ['a']),
      Playlist(id: 'seed_c', name: 'Seed C', trackIds: const ['a']),
    ]);

PlaylistList _timed() => PlaylistList([

      Playlist(id: 'old_new', name: 'Edited Today', trackIds: const ['a'],
          createdAt: 1000, updatedAt: 9000),

      Playlist(id: 'new_old', name: 'Made Today', trackIds: const ['a'],
          createdAt: 8000, updatedAt: 8000),
    ]);

PlaylistList _mostlyUndated() => PlaylistList([
      Playlist(id: 'zz', name: 'Aaa Undated', trackIds: const ['a']),
      Playlist(id: 'mm', name: 'Bbb Made Today', trackIds: const ['a'],
          createdAt: 8000, updatedAt: 8000),
      Playlist(id: 'aa', name: 'Ccc Undated', trackIds: const ['a']),
    ]);

void main() {
  group('with dates recorded', () {
    testWidgets('RECENTS is the most recently CREATED, not what was opened', (tester) async {
      await _pump(tester, recents: const [], sort: 'recents', lists: _timed());
      expect(_renderedOrder(tester).first, 'Made Today',
          reason: 'RECENTS must order by when the list was CREATED — this one was made last, so it is first, '
              'even though the other was edited more recently');
    });

    testWidgets('UPDATED is the most recently CHANGED, not created', (tester) async {
      await _pump(tester, recents: const [], sort: 'updated', lists: _timed());
      expect(_renderedOrder(tester).first, 'Edited Today',
          reason: 'UPDATED must order by when the list last CHANGED — this one was edited last, even though it '
              'was created first');
    });

    testWidgets('a real date outranks the file order, in both time sorters', (tester) async {
      await _pump(tester, recents: const [], sort: 'recents', lists: _mostlyUndated());
      expect(_renderedOrder(tester), [
        'Bbb Made Today',
        'Ccc Undated',
        'Aaa Undated',
      ], reason: 'the list with a real created-at must lead, and the undated ones keep the file order beneath '
          'it — newest added first');

      await _pump(tester, recents: const [], sort: 'updated', lists: _mostlyUndated());
      expect(_renderedOrder(tester).first, 'Bbb Made Today',
          reason: 'same rule for UPDATED — a recorded date beats no date');
    });
  });

  group('no dates recorded — every list on the device right now', () {
    testWidgets('RECENTS falls back to the FILE order, newest added first', (tester) async {
      await _pump(tester, recents: const []);
      expect(_renderedOrder(tester), [
        'Ccc Opened First',
        'Bbb Opened Middle',
        'Aaa Opened Last',
      ], reason: 'the file is append-ordered, so the LAST entry in it was created last and leads RECENTS');
    });

    testWidgets('and it is not alphabetical — that is the whole bug', (tester) async {
      await _pump(tester, recents: const []);
      expect(_renderedOrder(tester).first, isNot('Aaa Opened Last'),
          reason: 'RECENTS is alphabetical again, which is the report: every chip drawing one list');
    });

    testWidgets('A-Z is still alphabetical, when he asks for it', (tester) async {
      await _pump(tester, recents: const [], sort: 'alpha');
      expect(_renderedOrder(tester), [
        'Aaa Opened Last',
        'Bbb Opened Middle',
        'Ccc Opened First',
      ]);
    });

    testWidgets('the open order decides NOTHING any more', (tester) async {
      await _pump(tester, recents: ['aa', 'zz', 'mm']);
      final firstRun = _renderedOrder(tester);

      await _pump(tester, recents: ['mm', 'zz', 'aa']);
      expect(_renderedOrder(tester), firstRun,
          reason: 'the result moved with the open order — nothing about what he opened may decide this');
    });
  });

  group('seeded and custom, arranged together', () {
    testWidgets('the file order spans both kinds', (tester) async {
      await _pump(tester, recents: const [], mixed: _mixed());

      final order = _renderedOrder(tester);
      expect(order, ['Seed C', 'Custom B', 'Seed A'],
          reason: 'the two groups are being arranged apart again, so a custom list can never cross a seeded '
              'one — got: $order');
    });

    testWidgets('and A-Z is alphabetical ACROSS both groups', (tester) async {
      await _pump(tester, recents: const [], sort: 'alpha', mixed: _mixed());

      expect(_renderedOrder(tester), ['Custom B', 'Seed A', 'Seed C'],
          reason: 'alphabetical must span seeded and custom together, not each group alone');
    });
  });
}
