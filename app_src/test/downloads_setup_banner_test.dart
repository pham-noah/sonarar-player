library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:sonarar/screens/playlist_import_sheet.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

/// The build that fetches its engine offers it ONCE.
///
/// It used to be offered per row: `_row` returned the setup line instead of the
/// result, so a search with twenty hits was twenty identical "Set up downloads"
/// rows and no results at all. A banner above the list is the one place the same
/// sentence belongs.
DownloadManager _manager({required bool engineReady}) => DownloadManager(
      repo: LibraryRepository(),
      downloadDirOf: () => Directory.systemTemp,
      manifestOf: () => File('${Directory.systemTemp.path}/manifest.json'),
      downloadsAvailable: engineReady,
    );

Future<void> _pump(WidgetTester tester, {required bool engineReady}) async {
  tester.view.physicalSize = const Size(420, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.updateContext(const PlayContext(
    band: ContextBand.evening,
    whereabouts: Whereabouts.home,
    localHour: 19,
  ));

  final downloads = _manager(engineReady: engineReady);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      backgroundColor: kSkinCrimson.background,
      body: YoutubeSearchScreen(
        state: state,
        repo: LibraryRepository(),
        downloads: downloads,
        playlistStore: PlaylistSources(
          File('${Directory.systemTemp.path}/imported_playlists.json'),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a build without the engine offers it once, not once per row',
      (tester) async {
    await _pump(tester, engineReady: false);

    final banner = find.byKey(
      const Key('downloads-setup-banner'),
      skipOffstage: false,
    );
    expect(banner, findsOneWidget,
        reason: 'the setup affordance is missing, or it is repeated');

    expect(
      find.text('Set up downloads (one-time 14 MB)', skipOffstage: false),
      findsOneWidget,
      reason: 'the same sentence belongs in one place',
    );
  });

  testWidgets('a build that has its engine offers nothing to set up',
      (tester) async {
    await _pump(tester, engineReady: true);

    expect(
      find.byKey(const Key('downloads-setup-banner'), skipOffstage: false),
      findsNothing,
      reason: 'a full build must not ask the user to fetch what it shipped',
    );
  });
}
