library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlist_read.dart';

/// Real rows lifted from a live playlist page and its first continuation
/// response, so the parser meets the shapes YouTube actually sends.
String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

/// Every video id in a payload fragment, in order, once each.
List<String> _idsIn(Object? node) {
  final text = jsonEncode(node);
  final out = <String>[];
  for (final m in RegExp(r'i\.ytimg\.com/vi/([A-Za-z0-9_-]{11})/')
      .allMatches(text)) {
    final id = m.group(1)!;
    if (!out.contains(id)) out.add(id);
  }
  return out;
}

void main() {
  final page = _fixture('playlist_page.html');
  final continuation = _fixture('playlist_continuation.json');

  final pageData = jsonDecode(
    RegExp(r'var ytInitialData = (.*?);\n</script>', dotAll: true)
        .firstMatch(page)!
        .group(1)!,
  ) as Map<String, dynamic>;
  final sections =
      (pageData['contents']['twoColumnBrowseResultsRenderer']['tabs'][0]
          ['tabRenderer']['content']['sectionListRenderer']['contents'] as List)
          .cast<Map<String, dynamic>>();
  final playlistRows = _idsIn(sections[0]);

  final continued = jsonDecode(continuation) as Map<String, dynamic>;
  final appended =
      (continued['onResponseReceivedActions'][0]
              ['appendContinuationItemsAction']['continuationItems'] as List)
          .cast<Map<String, dynamic>>();
  final appendRows = _idsIn(appended);
  final sidebarRows = _idsIn(continued['sidebar']);
  final shelfRows = _idsIn(sections[1]);

  test('reads every page of the playlist, not just the first', () async {
    final posts = <String>[];
    final bodies = <String>[];

    final videos = await readPlaylistVideos(
      playlistId: 'PLfixture',
      fetch: (_) async => page,
      post: (url, body) async {
        posts.add(url);
        bodies.add(body);
        return continuation;
      },
    );

    // Three rows on the page, two more on the continuation.
    expect(videos.length, 5);
    expect(videos.map((v) => v.id).toList(), [
      playlistRows[0],
      playlistRows[1],
      playlistRows[2],
      appendRows[0],
      appendRows[1],
    ]);
    // Real fields survive the trip: escaped titles, the channel, the length.
    expect(videos.first.title, 'Wake Up, Get Up, Get Out There');
    expect(videos.first.author, isNotEmpty);
    expect(videos.first.duration, greaterThan(Duration.zero));

    expect(posts, ['https://www.youtube.com/youtubei/v1/browse?key=FIXTURE_KEY']);
    final body = jsonDecode(bodies.single) as Map<String, dynamic>;
    expect(body['continuation'], 'FIXTURE_TOKEN_1');
    // The client version comes from the page too: the rest of the payload was
    // built for it, and a guessed one gets a different shape back.
    expect(
      ((body['context'] as Map)['client'] as Map)['clientVersion'],
      '2.20990101.00.00',
    );
  });

  test('reads only the playlist rows, not the shelves around them', () async {
    final videos = await readPlaylistVideos(
      playlistId: 'PLfixture',
      fetch: (_) async => page,
      post: (_, __) async => continuation,
    );
    final ids = videos.map((v) => v.id).toSet();

    // The page has a second shelf and the continuation has a sidebar; both are
    // full of video ids that are not in the playlist. Importing them put videos
    // in a playlist that never contained them.
    expect(shelfRows, isNotEmpty);
    expect(sidebarRows, isNotEmpty);
    expect(ids.intersection(shelfRows.toSet()), isEmpty);
    expect(ids.intersection(sidebarRows.toSet()), isEmpty);
    expect(ids, hasLength(5));
  });

  test('stops when the continuation token stops moving', () async {
    var calls = 0;
    final videos = await readPlaylistVideos(
      playlistId: 'PLfixture',
      fetch: (_) async => page,
      post: (_, __) async {
        calls++;
        return continuation;
      },
    );

    // The second response repeats the first token and adds nothing: one post is
    // all this reader gets to make.
    expect(calls, 1);
    expect(videos.length, 5);
  });

  test('a reader without a post callback still reads the first page', () async {
    final videos = await readPlaylistVideos(
      playlistId: 'PLfixture',
      fetch: (_) async => page,
    );
    expect(videos.length, 3);
  });

  test('an empty or unreachable page is an empty result, not a crash', () async {
    expect(
      await readPlaylistVideos(playlistId: 'PLfixture', fetch: (_) async => null),
      isEmpty,
    );
    expect(
      await readPlaylistVideos(
        playlistId: 'PLfixture',
        fetch: (_) async => page,
        post: (_, __) async => null,
      ),
      hasLength(3),
    );
  });
}
