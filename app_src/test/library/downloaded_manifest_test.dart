import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/downloaded_tracks.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sonarar_manifest');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  DownloadedTrack track(String id) => DownloadedTrack(
        id: id,
        title: 'Song $id',
        artist: 'Someone',
        album: 'Downloaded',
        durationSeconds: 120,
        fileName: 'Downloaded/$id.m4a',
        coverName: 'Downloaded/$id.jpg',
      );

  test('a fresh phone with no manifest gets one, not a dropped download',
      () async {
    final manifest = File('${tmp.path}${Platform.pathSeparator}library_manifest.json');
    expect(manifest.existsSync(), isFalse);

    final wrote = await addToManifest(manifest: manifest, track: track('abc'));

    expect(wrote, isTrue, reason: 'the first download must reach the library');
    expect(manifest.existsSync(), isTrue);

    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final tracks = raw['tracks'] as List;
    expect(tracks, hasLength(1));
    expect((tracks.first as Map)['id'], 'abc');
  });

  test('a second download appends instead of replacing the first', () async {
    final manifest = File('${tmp.path}${Platform.pathSeparator}library_manifest.json');
    await addToManifest(manifest: manifest, track: track('one'));
    await addToManifest(manifest: manifest, track: track('two'));

    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    final ids = (raw['tracks'] as List).map((t) => (t as Map)['id']).toList();
    expect(ids, ['one', 'two']);
  });

  test('the same video twice does not duplicate the row', () async {
    final manifest = File('${tmp.path}${Platform.pathSeparator}library_manifest.json');
    await addToManifest(manifest: manifest, track: track('same'));
    await addToManifest(manifest: manifest, track: track('same'));

    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    expect((raw['tracks'] as List), hasLength(1));
  });

  test('a manifest missing its tracks array is refused, not overwritten',
      () async {
    final manifest = File('${tmp.path}${Platform.pathSeparator}library_manifest.json')
      ..writeAsStringSync('{"broken": true}');

    final wrote = await addToManifest(manifest: manifest, track: track('x'));

    expect(wrote, isFalse);
    expect(await manifest.readAsString(), '{"broken": true}',
        reason: 'an unknown file must not be clobbered');
  });
}
