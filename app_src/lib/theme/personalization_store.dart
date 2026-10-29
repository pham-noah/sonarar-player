library;

import 'dart:io';

import 'personalization.dart';

/// The live personalization document, next to the other state files.
///
/// Separate from `theme_presets.json` on purpose: presets are things the user
/// saves and can throw away, while this is what the app is wearing right now —
/// including the half-finished backdrop they are still framing.
class PersonalizationStore {
  PersonalizationStore(this.file);

  final File file;

  Future<Personalization> load() async {
    try {
      if (!file.existsSync()) return Personalization.defaults;
      return Personalization.decode(await file.readAsString());
    } on FileSystemException {
      return Personalization.defaults;
    }
  }

  Future<void> save(Personalization p) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(p.encode());
    } on FileSystemException {
      // ignore: empty_catches
    }
  }
}
