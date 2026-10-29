import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_bundle.dart';
import 'package:sonarar/art/art_spec.dart';

/// A bundle is a folder; scanning is what turns folders into art.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sonarar-library');
    Directory('${root.path}/art').createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  File picture(String bundle, String name) {
    final dir = Directory('${root.path}/art/$bundle')..createSync(recursive: true);
    return File('${dir.path}/$name')..writeAsStringSync('not really a jpeg');
  }

  test('pictures in a folder are frames of one bundle', () {
    picture('night', 'a.jpg');
    picture('night', 'b.png');

    final bundles = scanArtBundles(root.path);

    expect(bundles, hasLength(1));
    expect(bundles.first.name, 'night');
    expect(bundles.first.set.pieces, hasLength(2));
    expect(bundles.first.set.pieces.first.assetPath, startsWith('file:'));
    expect(bundles.first.set.pieces.first.key, 'night/a.jpg');
  });

  test('a folder with no pictures is not a bundle', () {
    Directory('${root.path}/art/empty').createSync();

    expect(scanArtBundles(root.path), isEmpty);
  });

  test('loose files in art/ are not bundles either', () {
    File('${root.path}/art/stray.jpg').writeAsStringSync('x');

    expect(scanArtBundles(root.path), isEmpty);
  });

  test('bundles come back in a stable order, whatever the filesystem says', () {
    picture('zeta', 'a.jpg');
    picture('alpha', 'a.jpg');

    final names = scanArtBundles(root.path).map((b) => b.name).toList();

    expect(names, ['alpha', 'zeta']);
  });

  test('a bundle with no library at all is empty, not a crash', () {
    expect(scanArtBundles(null), isEmpty);
    expect(scanArtBundles('/no/such/place'), isEmpty);
  });

  test('the spec beside the pictures is read with them', () {
    picture('night', 'a.jpg');
    ArtSpec.write(Directory('${root.path}/art/night'), const ArtSpec(zoom: 1.5));

    final piece = scanArtBundles(root.path).first.set.pieces.first;

    expect(piece.spec.zoom, 1.5);
  });
}
