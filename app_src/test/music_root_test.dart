import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/music_root.dart';

/// A folder is a library only when it carries the manifest. Choosing anything
/// else would read as an empty library, so the picker refuses it.
void main() {
  test('a folder with a manifest is a library', () async {
    final dir = await Directory.systemTemp.createTemp('sonarar-lib');
    addTearDown(() => dir.delete(recursive: true));
    File('${dir.path}/library_manifest.json').writeAsStringSync('{"tracks":[]}');

    expect(await MusicRoot.isLibrary(dir.path), isTrue);
  });

  test('a bare folder is not', () async {
    final dir = await Directory.systemTemp.createTemp('sonarar-bare');
    addTearDown(() => dir.delete(recursive: true));

    expect(await MusicRoot.isLibrary(dir.path), isFalse);
  });
}
