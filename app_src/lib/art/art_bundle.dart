library;

import 'dart:io';

import '../theme/skin.dart';
import 'art_spec.dart';
import 'skin_art.dart';

/// A folder of pictures is one art set.
///
/// A bundle is deliberately just a directory: `<library>/art/<name>/` holds any
/// number of images and those images are its frames. There is no manifest to
/// get wrong, no list to keep in sync, and adding art is copying a file in.
class ArtBundle {
  const ArtBundle({required this.name, required this.set});

  final String name;
  final SkinArtSet set;
}

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

/// Scans `<library>/art/` for bundles. A folder with no pictures in it is not a
/// bundle — an empty entry in the list would look like a broken import.
List<ArtBundle> scanArtBundles(String? libraryRoot) {
  if (libraryRoot == null) return const [];
  final root = Directory('$libraryRoot/art');
  if (!root.existsSync()) return const [];

  final bundles = <ArtBundle>[];
  for (final entry in root.listSync(followLinks: false)) {
    if (entry is! Directory) continue;
    final files = <File>[];
    try {
      for (final f in entry.listSync(followLinks: false)) {
        if (f is! File) continue;
        final lower = f.path.toLowerCase();
        if (_imageExtensions.any(lower.endsWith)) files.add(f);
      }
    } on FileSystemException {
      continue;
    }
    if (files.isEmpty) continue;
    files.sort((a, b) => a.path.compareTo(b.path));

    final name = entry.path.split(Platform.pathSeparator).last;
    bundles.add(
      ArtBundle(
        name: name,
        set: SkinArtSet(SkinId.abyss, [
          for (final f in files)
            SkinArt(
              key: '$name/${f.uri.pathSegments.last}',
              // `file:` marks a picture on disk rather than a shipped asset.
              assetPath: 'file:${f.path}',
              aspect: 1,
              spec: ArtSpec.read(entry),
            ),
        ]),
      ),
    );
  }
  bundles.sort((a, b) => a.name.compareTo(b.name));
  return bundles;
}

/// Makes a bundle from one picture, so the feature has a door before the user
/// has a folder of art to drop in.
Directory createBundleFrom(String libraryRoot, File picture) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final dir = Directory('$libraryRoot/art/bundle-$stamp')
    ..createSync(recursive: true);
  final name = picture.path.split(Platform.pathSeparator).last;
  picture.copySync('${dir.path}/$name');
  return dir;
}
