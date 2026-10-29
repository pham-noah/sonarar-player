import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'constants.dart';

/// Where the music lives, chosen once and remembered.
///
/// It cannot live in prefs.json, because prefs are read from a directory
/// resolved *from* this path — a boot-time circle. One small file in app
/// support solves it without a dependency.
class MusicRoot {
  const MusicRoot._();

  static const String _fileName = 'music_root.txt';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  /// The chosen folder, or the default when nothing has been chosen.
  static Future<String> read() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        final path = (await file.readAsString()).trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    return kAndroidLibraryRoot;
  }

  static Future<void> write(String path) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(path);
  }

  /// A folder is a Sonarar library only if it carries the manifest that names
  /// every track. Pointing at anything else would look like an empty library.
  static Future<bool> isLibrary(String path) =>
      File('$path${Platform.pathSeparator}$kManifestFileName').exists();
}
