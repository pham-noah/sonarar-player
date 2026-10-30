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
Directory createFolderFrom(String libraryRoot, File picture, {String? name}) {
  final folder = _uniqueFolder(libraryRoot, name ?? _stampName());
  folder.createSync(recursive: true);
  picture.copySync('${folder.path}/${_fileName(picture)}');
  return folder;
}

/// One folder is a set of pictures, not a picture. Adding to an existing folder
/// is how a place gets something to walk through as tracks change.
File addToFolder(Directory folder, File picture) {
  var target = File('${folder.path}/${_fileName(picture)}');
  var n = 2;
  while (target.existsSync()) {
    final name = _fileName(picture);
    final dot = name.lastIndexOf('.');
    final stem = dot <= 0 ? name : name.substring(0, dot);
    final ext = dot <= 0 ? '' : name.substring(dot);
    target = File('${folder.path}/$stem-$n$ext');
    n++;
  }
  return picture.copySync(target.path);
}

/// Renames the folder on disk. The name is the folder label in Personalize, so a
/// row of `bundle-1730…` is a row nobody can read.
Directory renameFolder(Directory folder, String name) {
  final target = Directory('${folder.parent.path}/${_dashed(name)}');
  if (target.path == folder.path) return folder;
  if (target.existsSync()) return folder;
  return folder.renameSync(target.path);
}

/// Takes one picture out of a folder. The folder itself stays — removing a
/// folder is a different, louder action.
bool removeFromFolder(Directory folder, String name) {
  final f = File('${folder.path}/$name');
  if (!f.existsSync()) return false;
  f.deleteSync();
  return true;
}

/// Deletes the folder and everything in it. The pictures are copies made by the
/// app, so this is not the user's original photo.
void deleteFolder(Directory folder) {
  if (folder.existsSync()) folder.deleteSync(recursive: true);
}

String _stampName() => 'folder-${DateTime.now().millisecondsSinceEpoch}';

Directory _uniqueFolder(String libraryRoot, String name) {
  var dir = Directory('$libraryRoot/art/${_dashed(name)}');
  var n = 2;
  while (dir.existsSync()) {
    dir = Directory('$libraryRoot/art/${_dashed(name)}-$n');
    n++;
  }
  return dir;
}

String _fileName(File f) => f.path.split(Platform.pathSeparator).last;

/// No spaces: these are folder names other tools have to survive too.
String _dashed(String name) {
  final cleaned = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return cleaned.isEmpty ? _stampName() : cleaned;
}
