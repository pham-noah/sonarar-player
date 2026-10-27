// ignore_for_file: avoid_print
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlist_read.dart';

int lastStatus = 0;
int lastLen = 0;

Future<String?> _fetch(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0 Safari/537.36');
    final res = await req.close();
    lastStatus = res.statusCode;
    final bytes = await res.fold<List<int>>([], (a, b) => a..addAll(b));
    lastLen = bytes.length;
    final body = utf8.decode(bytes, allowMalformed: true);

    final i = body.indexOf('"lockupViewModel":{"contentImage"');
    if (i > 0) {
      final k = body.indexOf('"lockupMetadataViewModel"', i);
      print('META: ${body.substring(k, k + 700)}');
      print('IDS in thumbs: ${RegExp(r"i\.ytimg\.com/vi/([A-Za-z0-9_-]{11})/").allMatches(body).length}');
    } else {
      final j = body.indexOf('"contentId"');
      print('CONTENTID AT: ${body.substring(j < 60 ? 0 : j - 60, j + 700)}');
    }
    if (res.statusCode != 200) return null;
    return body;
  } finally {
    client.close();
  }
}

void main() {
  test('his real playlist, read by our own reader', () async {
    final videos = await readPlaylistVideos(
      playlistId: 'PLnO9OSU1eJ5fV53hv7HLZPTMcKVzCJBrH',
      fetch: _fetch,
    );
    print('READER -> ${videos.length} videos');
    for (final v in videos.take(8)) {
      print('READER   ${v.id}  dur=${v.duration?.inSeconds}  "${v.title}"');
    }
    expect(videos, isNotEmpty,
        reason: 'the replacement reader found nothing either — the problem is deeper than the channelId skip');
  }, timeout: const Timeout(Duration(seconds: 150)));
}
