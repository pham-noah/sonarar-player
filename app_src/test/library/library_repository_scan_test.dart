library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/library_repository.dart';

/// The repository is where the manifest and the disk meet. These tests put both
/// in a real folder and check which one wins.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sonarar-repo-test');
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void put(String relative, {int bytes = 8}) {
    final file = File('${root.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 0));
  }

  void manifest(List<String> files) {
    final body = jsonEncode({
      'tracks': [
        for (var i = 0; i < files.length; i++)
          {
            'id': 't$i',
            'title': 'Song $i',
            'artist': 'Artist',
            'album': 'Album',
            'duration_s': 120,
            'file': files[i],
          },
      ],
    });
    File('${root.path}/library_manifest.json').writeAsStringSync(body);
  }

  Future<LibraryRepository> loaded() async {
    final repo = LibraryRepository()..root = root.path;
    await repo.load();
    return repo;
  }

  test('the disk answers where a file is, not the manifest', () async {
    put('Moved/01 Song.mp3');
    manifest(['Artist/Album/01 Song.mp3']);

    final repo = await loaded();

    expect(repo.tracks, hasLength(1));
    expect(repo.absoluteFor(repo.tracks.single),
        '${root.path}/Moved/01 Song.mp3');
    expect(repo.missingIds, isEmpty,
        reason: 'it moved, it did not vanish — the track still plays');
  });

  test('a track whose file is nowhere is reported missing, not hidden',
      () async {
    put('Artist/Album/01 Song.mp3');
    manifest(['Artist/Album/01 Song.mp3', 'Artist/Album/02 Gone.mp3']);

    final repo = await loaded();

    expect(repo.tracks, hasLength(2), reason: 'the record is kept');
    expect(repo.missingIds, {'t1'});
    // The stale path is still handed back, so a player that wants to try it can
    // — it is the caller's choice, not a silent lie.
    expect(repo.absoluteFor(repo.tracks[1]),
        '${root.path}/Artist/Album/02 Gone.mp3');
  });

  test('refresh notices a file that appeared, without rereading the manifest',
      () async {
    put('Artist/Album/01 Song.mp3');
    manifest(['Artist/Album/01 Song.mp3', 'Artist/Album/02 Later.mp3']);

    final repo = await loaded();
    expect(repo.missingIds, {'t1'});

    put('Artist/Album/02 Later.mp3');
    final changed = await repo.refresh();

    expect(changed, isTrue);
    expect(repo.missingIds, isEmpty);
    expect(repo.tracks, hasLength(2));
  });

  test('refresh reports no change when nothing on disk moved', () async {
    put('Artist/Album/01 Song.mp3');
    manifest(['Artist/Album/01 Song.mp3']);

    final repo = await loaded();

    expect(await repo.refresh(), isFalse,
        reason: 'a resume that changes nothing must not rebuild the UI');
  });

  test('a chosen folder with no manifest reads as empty, as before', () async {
    put('Artist/Album/01 Song.mp3');

    final repo = await loaded();

    expect(repo.tracks, isEmpty);
    expect(repo.missingIds, isEmpty);
  });
}
