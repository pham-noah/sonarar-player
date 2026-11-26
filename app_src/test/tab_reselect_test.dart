library;

// Tapping the Library tab while already on it should return the list to its
// first row — the gesture every list app has, and the only way back from three
// hundred rows down other than flicking until it stops. The bar had one
// behaviour for a tab: navigate. Re-tapping re-navigated to the same tab, which
// rebuilds the screen and leaves the scroll position exactly where it was, so
// the tap looked like it did nothing.
//
// The request travels as a counter (`topRequest`), the same way `searchRequest`
// already does, because the position lives in the screen's own controller. That
// makes the motion rule testable here: a re-tap glides, and under Reduce Motion
// it arrives at once, because a 200ms glide is still a glide.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/theme/skin.dart';

Track _t(int n) => Track(
      id: 't$n',
      title: 'Track $n',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(seconds: 180),
      file: 'music/t$n.m4a',
      cover: 'covers/t$n.jpg',
      gainDb: 0,
    );

LibraryScreenView _view({int topRequest = 0}) => LibraryScreenView(
      tracks: [for (var i = 0; i < 60; i++) _t(i)],
      coverPathFor: (_) => null,
      skin: kSkinCrimson,
      libraryRoot: '/music',
      playlists: PlaylistList([
        Playlist(id: 'p1', name: 'JPOP', trackIds: const ['t0', 't1']),
      ]),
      pinnedPlaylistIds: const [],
      topRequest: topRequest,
      onPlay: (_) {},
      onCreatePlaylist: (_) {},
      onDeletePlaylist: (_) {},
      onPlayPlaylist: (_) {},
      onTogglePlay: (_) {},
      onQueue: (_) => SwipeOutcome.queued,
      onLike: (_) => SwipeOutcome.liked,
      onAddSongsTo: (_) {},
    );

/// The library's own list, not the horizontal racks above it.
final _list = find
    .byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down)
    .first;

double _offset(WidgetTester tester) =>
    tester.state<ScrollableState>(_list).position.pixels;

Future<void> _pump(WidgetTester tester,
    {required bool reduceMotion, int topRequest = 0}) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Material(child: LibraryScreen(view: _view(topRequest: topRequest))),
    ),
  ));
  await tester.pump();
}

/// The library opens on its playlists; the songs are one segment away, and the
/// list that can scroll deep is the songs page.
Future<void> _openSongs(WidgetTester tester) async {
  final songs = find.text('SONGS');
  if (songs.evaluate().isNotEmpty) {
    await tester.tap(songs.first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('a re-tap on the Library tab returns the list to its first row',
      (tester) async {
    await _pump(tester, reduceMotion: false);

    await _openSongs(tester);
    await tester.drag(_list, const Offset(0, -2400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_offset(tester), greaterThan(500),
        reason: 'The list did not scroll, so there is nothing to come back '
            'from and this test would pass without the fix.');

    // The shell bumps the counter; the screen does the moving.
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Material(child: LibraryScreen(view: _view(topRequest: 1))),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_offset(tester), greaterThan(0),
        reason: 'The glide finished inside one frame, so the tap is a jump for '
            'everyone — a re-tap should feel like travel, not teleportation.');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_offset(tester), 0,
        reason: 'Re-tapping the tab you are already on left the list where it '
            'was, so the only way back to the top of a long library is to flick '
            'until it stops.');
  });

  testWidgets('under Reduce Motion the list arrives at once', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _openSongs(tester);
    await tester.drag(_list, const Offset(0, -2400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_offset(tester), greaterThan(500));

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Material(child: LibraryScreen(view: _view(topRequest: 1))),
      ),
    ));
    await tester.pump();

    expect(_offset(tester), 0,
        reason: 'With animations disabled the list must be at the top after one '
            'frame: a shortened glide is still a glide, and the tap asks to '
            'arrive.');
  });

  testWidgets('tapping a tab you are not on navigates instead', (tester) async {
    final selected = <AppTab>[];
    final reselected = <AppTab>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: Builder(
          builder: (context) => TabBarView2(
            skin: kSkinCrimson,
            current: AppTab.library,
            onSelect: selected.add,
            onReselect: reselected.add,
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_rounded));
    await tester.pump();
    expect(selected, [AppTab.home],
        reason: 'Tapping another tab must still navigate; a re-tap handler that '
            'swallowed it would strand the user on one tab.');
    expect(reselected, isEmpty);

    await tester.tap(find.byIcon(Icons.library_music_rounded));
    await tester.pump();
    expect(reselected, [AppTab.library],
        reason: 'Re-tapping the tab in force did not ask anyone to return to '
            'the top, so the tap is a rebuild that looks like a no-op.');
    expect(selected, [AppTab.home],
        reason: 'A re-tap navigated to the tab already showing, which is the '
            'behaviour this replaces.');

    // And a re-tap on a tab whose screen is one tall does not ask for a scroll
    // it cannot do — the shell ignores it, but the bar must tell the truth.
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    expect(selected.last, AppTab.settings);
  });
}
