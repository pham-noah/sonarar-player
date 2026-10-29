import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/library_repository.dart';

/// A chosen folder that is not a library reads as empty. Falling back to the
/// demo library shipped in the APK would look exactly like losing the music.
void main() {
  test('a chosen folder without a manifest is empty, not the bundled demo', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('sonarar-root');
    addTearDown(() => dir.delete(recursive: true));

    final repo = LibraryRepository()..root = dir.path;
    await repo.load();

    expect(repo.tracks, isEmpty);
    expect(repo.loadedFrom, isNull);
  });

  test('a chosen folder with a manifest is read from it', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = await Directory.systemTemp.createTemp('sonarar-root');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}/library_manifest.json').writeAsStringSync('''
      {"version":1,"tracks":[{"id":"x","title":"From Elsewhere","artist":"Nobody",
      "album":"A","duration_s":120,"file":"x.mp3","cover":null,"gain_db":null}]}
    ''');

    final repo = LibraryRepository()..root = dir.path;
    await repo.load();

    expect(repo.tracks.single.title, 'From Elsewhere');
    expect(repo.libraryRoot, dir.path);
  });
}
