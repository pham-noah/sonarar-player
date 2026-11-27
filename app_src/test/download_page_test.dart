library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/playlist_import_sheet.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

/// The download page says what happened: which rows found nothing, which query
/// they belong to, and how a failed search reads. Each of those used to be a
/// blank area under a search field.
Track _t(String id, String artist) => Track(
  id: id,
  title: 'Title $id',
  artist: artist,
  album: 'album',
  duration: const Duration(minutes: 3),
  file: '$id.opus',
  cover: '',
  gainDb: null,
);

const _hit = SearchHit(
  id: 'aaaaaaaaaaa',
  title: 'Living With Determination',
  channel: 'ATLUS Sound Team',
  duration: Duration(seconds: 203),
);

DownloadManager _manager() => DownloadManager(
  repo: LibraryRepository(),
  downloadDirOf: () => Directory.systemTemp,
  manifestOf: () => File('${Directory.systemTemp.path}/manifest.json'),
  downloadsAvailable: true,
  capabilitiesOf: () async => const YtdlpCapabilities(engine: true),
);

Future<void> _pump(
  WidgetTester tester, {
  Future<List<SearchHit>> Function(String)? search,
  List<Track> library = const [],
}) async {
  tester.view.physicalSize = const Size(412, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary(library);
  state.updateContext(
    const PlayContext(
      band: ContextBand.evening,
      whereabouts: Whereabouts.home,
      localHour: 19,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: kSkinCrimson.background,
        body: YoutubeSearchScreen(
          state: state,
          repo: LibraryRepository(),
          downloads: _manager(),
          playlistStore: PlaylistSources(
            File('${Directory.systemTemp.path}/imported_playlists.json'),
          ),
          search: search ?? (q) async => const [_hit],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const Key('search-submit')));
  await tester.pumpAndSettle();
}

/// The one thing at the end of a search row, and which claim wins when two are
/// true at once. Every case is a state the page can really be in, and the only
/// one a person can act on is the one drawn.
RowAction _action({
  bool inLibrary = false,
  bool playable = true,
  bool queued = false,
  bool failed = false,
  bool officialOnly = false,
  bool official = true,
  bool engineMissing = false,
}) => rowActionFor(
  inLibrary: inLibrary,
  playable: playable,
  queued: queued,
  failed: failed,
  officialOnly: officialOnly,
  official: official,
  engineMissing: engineMissing,
);

void main() {
  group('the control at the end of a row', () {
    test('a row with nothing happening offers the download', () {
      expect(_action(), RowAction.download);
    });

    test('a track already in the library plays, and only plays', () {
      expect(_action(inLibrary: true), RowAction.play);
      // Downloaded but not indexed yet: nothing to play, and offering to fetch
      // a file already on disk would fetch it twice.
      expect(_action(inLibrary: true, playable: false), RowAction.done);
    });

    test('a queued download offers to stop it, not to start it', () {
      expect(_action(queued: true), RowAction.cancel);
    });

    test('a running download outranks the failure that came before it', () {
      // Retrying leaves the old reason on the row until the new job starts; the
      // row must not offer "try again" for a download already going.
      expect(_action(queued: true, failed: true), RowAction.cancel);
    });

    test('a failed download offers to try again', () {
      expect(_action(failed: true), RowAction.retry);
    });

    test('a finished track outranks every transient state', () {
      expect(
        _action(inLibrary: true, queued: true, failed: true),
        RowAction.play,
      );
    });

    test('a build with no engine says so on the row, once, not per tap', () {
      expect(_action(engineMissing: true), RowAction.unavailable);
    });

    test('official only puts a block on everything else', () {
      expect(_action(officialOnly: true, official: false), RowAction.blocked);
      expect(_action(officialOnly: true), RowAction.download);
    });
  });

  testWidgets('a search that finds nothing says so, for the word it searched', (
    tester,
  ) async {
    await _pump(tester, search: (q) async => const []);
    await _search(tester, 'zebra');

    expect(
      find.text('Nothing on YouTube for "zebra".'),
      findsOneWidget,
      reason: 'an empty result and a broken search looked the same: nothing',
    );
  });

  testWidgets('the clear button empties the field and the rows under it', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('search-clear')), findsNothing);

    await _search(tester, 'persona');
    expect(find.text(_hit.title), findsOneWidget);
    expect(
      find.byKey(const Key('search-clear')),
      findsOneWidget,
      reason: 'the only way back to the whole library was deleting by hand',
    );

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
    expect(find.text(_hit.title), findsNothing);
  });

  testWidgets('a search that fails says what to do, not what threw', (
    tester,
  ) async {
    await _pump(
      tester,
      search: (q) async => throw const SocketException('no route to host'),
    );
    await _search(tester, 'persona');

    expect(
      find.text("Couldn't reach YouTube. Check the connection and try again."),
      findsOneWidget,
    );
    for (final e in find.byType(Text).evaluate()) {
      final text = (e.widget as Text).data ?? '';
      expect(
        text.contains('SocketException'),
        isFalse,
        reason: 'the exception is for the log, not for the person reading it',
      );
    }
  });

  testWidgets('rows belong to the query that asked for them', (tester) async {
    await _pump(tester);
    await _search(tester, 'persona');
    expect(find.text(_hit.title), findsOneWidget);

    // Typing is enough: the rows under a new word are about the old one.
    await tester.enterText(find.byType(TextField), 'smtv');
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text(_hit.title),
      findsNothing,
      reason: "last search's results sat under a word they were never about",
    );
  });

  testWidgets('the page suggests the artists it already holds', (tester) async {
    await _pump(
      tester,
      library: [
        _t('a', 'Mitski'),
        _t('b', 'Mitski'),
        _t('c', 'Sufjan Stevens'),
      ],
    );

    expect(
      find.byKey(const Key('artist-suggestion-Mitski')),
      findsOneWidget,
      reason:
          'a search page with an empty body said nothing about what to type',
    );
    // Most tracks first: the artist the library holds most of leads.
    final mitski = tester.getTopLeft(
      find.byKey(const Key('artist-suggestion-Mitski')),
    );
    final sufjan = tester.getTopLeft(
      find.byKey(const Key('artist-suggestion-Sufjan Stevens')),
    );
    expect(mitski.dy <= sufjan.dy, isTrue);

    await tester.tap(find.byKey(const Key('artist-suggestion-Mitski')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Mitski',
    );
    expect(find.text(_hit.title), findsOneWidget);
  });
}
