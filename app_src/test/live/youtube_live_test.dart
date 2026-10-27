@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  late YoutubeExplode yt;

  setUp(() => yt = YoutubeExplode());
  tearDown(() => yt.close());

  test('SEARCH returns real results', () async {
    final results = await yt.search.search('persona 5 royal soundtrack');
    // ignore: avoid_print
    print('SEARCH -> ${results.length} results');
    for (final v in results.take(5)) {
      // ignore: avoid_print
      print('  ${v.id.value}  ${v.title}  [${v.author}]  ${v.duration}');
    }
    expect(results, isNotEmpty,
        reason: 'the Dart port could not search YouTube at all — the feature cannot work');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('A STREAM URL RESOLVES — the part YouTube breaks first', () async {
    final results = await yt.search.search('persona 5 royal - life will change');
    expect(results, isNotEmpty);
    final id = results.first.id.value;

    final manifest = await yt.videos.streamsClient.getManifest(id);
    final audio = manifest.audioOnly.withHighestBitrate();
    // ignore: avoid_print
    print('STREAM -> $id  container=${audio.container.name}  '
        'bitrate=${audio.bitrate.kiloBitsPerSecond.round()}kbps  '
        'size=${(audio.size.totalBytes / 1048576).toStringAsFixed(1)}MB');

    expect(audio.size.totalBytes, greaterThan(0));

    var read = 0;
    await for (final chunk in yt.videos.streamsClient.get(audio)) {
      read += chunk.length;
      if (read > 64 * 1024) break;
    }
    // ignore: avoid_print
    print('BYTES -> read $read bytes from the stream');
    expect(read, greaterThan(0),
        reason: 'the URL resolved but served NO BYTES — this is the documented failure mode');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
