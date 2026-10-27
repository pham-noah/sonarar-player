// ignore_for_file: avoid_print
@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('what does "spin" return, and what does the filter think', () async {
    final yt = YoutubeExplode();
    addTearDown(yt.close);
    final results = await yt.search.search('spin');
    print('SPIN -> ${results.length} results');
    final hits = [
      for (final v in results.take(30))
        SearchHit(
          id: v.id.value, title: v.title, channel: v.author,
          duration: v.duration ?? Duration.zero,
        ),
    ];

    final vouched = {
      for (final h in hits)
        if (h.looksLikeOfficialRelease) h.channel.toLowerCase(),
    };
    print('SPIN vouched channels: $vouched');
    for (final hit in hits.take(14)) {
      final verdict = hit.isOfficialGiven(vouched) ? 'OFFICIAL' : 'refused ';
      final why = hit.looksLikeOfficialRelease
          ? 'own marker'
          : (vouched.contains(hit.channel.toLowerCase()) ? 'channel vouched' : '-');
      print('SPIN   [$verdict] ($why) "${hit.title}"  <- "${hit.channel}"');
    }
  }, timeout: const Timeout(Duration(seconds: 90)));
}
