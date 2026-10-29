import 'dart:convert';
import 'dart:io';

/// What a backup is: the `.state` folder, verbatim, in one file.
///
/// Everything that is expensive to rebuild by hand lives there — tags, likes,
/// playlists, bonds, theme presets, play history, bookmarks — and none of it
/// can be recovered from the audio files once the folder is gone. A reinstall
/// or a wipe of the music folder takes it, so it gets a copy the user can move.
const String kBackupFormat = 'sonarar-state';
const int kBackupVersion = 1;

/// Only the files the app owns and can rebuild its UI from.
const List<String> _keepSuffixes = ['.json', '.jsonl'];

class BackupReport {
  const BackupReport({
    this.file,
    this.files = 0,
    this.error,
    this.savedCurrentTo,
    this.skipped = const [],
  });

  final File? file;
  final int files;
  final String? error;
  final Directory? savedCurrentTo;
  final List<String> skipped;

  bool get ok => error == null && file != null;
}

class RestoreReport {
  const RestoreReport({
    this.files = 0,
    this.error,
    this.savedCurrentTo,
    this.skipped = const [],
  });

  final int files;
  final String? error;
  final Directory? savedCurrentTo;
  final List<String> skipped;

  bool get ok => error == null && files > 0;
}

class BackupService {
  BackupService({
    required this.stateDirectory,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory stateDirectory;
  final DateTime Function() _clock;

  /// One JSON object naming the format, so a restore can refuse a file that is
  /// not ours instead of writing junk over the state folder.
  Future<BackupReport> writeTo(Directory dest, {String? appVersion}) async {
    final files = await _collect();
    if (files.isEmpty) {
      return const BackupReport(error: 'There is no state to back up yet.');
    }
    final stamp = _stamp(_clock());
    final payload = const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormat,
      'version': kBackupVersion,
      'createdAt': _clock().toIso8601String(),
      if (appVersion != null) 'app': appVersion,
      'files': files,
    });
    try {
      await dest.create(recursive: true);
      final target = File('${dest.path}/sonarar-backup-$stamp.json');
      await target.writeAsString(payload, flush: true);
      return BackupReport(file: target, files: files.length);
    } on FileSystemException catch (e) {
      return BackupReport(error: 'Could not write the backup: ${e.message}');
    }
  }

  /// Newest first, so the list a user picks from leads with the one they just
  /// made.
  static List<File> findBackups(Directory dest) {
    final dir = Directory(dest.path);
    if (!dir.existsSync()) return const [];
    final found = <File>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.startsWith('sonarar-backup-') || !name.endsWith('.json')) {
        continue;
      }
      found.add(e);
    }
    found.sort((a, b) => b.path.compareTo(a.path));
    return found;
  }

  /// Reads the file and copies it over the live state.
  ///
  /// The current state is copied aside first: a restore that turns out to be
  /// the wrong backup has to be undoable, or nobody dares press the button.
  Future<RestoreReport> restore(File source) async {
    Map<String, dynamic> payload;
    try {
      final raw = await source.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const RestoreReport(error: 'That file is not a Sonarar backup.');
      }
      payload = decoded;
    } on FormatException {
      return const RestoreReport(error: 'That file is not readable JSON.');
    } on FileSystemException catch (e) {
      return RestoreReport(error: 'Could not read the backup: ${e.message}');
    }

    if (payload['format'] != kBackupFormat) {
      return const RestoreReport(error: 'That file is not a Sonarar backup.');
    }
    final version = payload['version'];
    if (version is! int || version > kBackupVersion) {
      return const RestoreReport(
        error: 'That backup was made by a newer version of Sonarar.',
      );
    }
    final files = payload['files'];
    if (files is! Map || files.isEmpty) {
      return const RestoreReport(error: 'That backup contains no data.');
    }

    final skipped = <String>[];
    final writes = <String, String>{};
    for (final entry in files.entries) {
      final name = entry.key;
      final body = entry.value;
      if (name is! String || body is! String) {
        skipped.add('$name (unreadable)');
        continue;
      }
      // A backup is data, not a way to write anywhere on the device.
      if (name.contains('/') || name.contains('\\') || name.startsWith('.')) {
        skipped.add(name);
        continue;
      }
      if (!_keepSuffixes.any(name.endsWith)) {
        skipped.add(name);
        continue;
      }
      if (!_parses(name, body)) {
        skipped.add('$name (malformed)');
        continue;
      }
      writes[name] = body;
    }

    if (writes.isEmpty) {
      return RestoreReport(
        error: 'Nothing in that backup could be restored.',
        skipped: skipped,
      );
    }

    Directory? aside;
    try {
      aside = await _copyCurrentStateAside();
      for (final entry in writes.entries) {
        final target = File('${stateDirectory.path}/${entry.key}');
        // Temp then rename: a half-written prefs.json is a wiped app.
        final tmp = File('${target.path}.restoring');
        await tmp.writeAsString(entry.value, flush: true);
        await tmp.rename(target.path);
      }
    } on FileSystemException catch (e) {
      return RestoreReport(
        error: 'Restore stopped: ${e.message}',
        savedCurrentTo: aside,
        skipped: skipped,
      );
    }

    return RestoreReport(
      files: writes.length,
      savedCurrentTo: aside,
      skipped: skipped,
    );
  }

  Future<Map<String, String>> _collect() async {
    final out = <String, String>{};
    if (!stateDirectory.existsSync()) return out;
    for (final e in stateDirectory.listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (name.startsWith('.')) continue;
      if (!_keepSuffixes.any(name.endsWith)) continue;
      // A file being written mid-scan is not worth failing the whole backup.
      try {
        out[name] = await e.readAsString();
      } on FileSystemException {
        continue;
      }
    }
    return out;
  }

  Future<Directory?> _copyCurrentStateAside() async {
    if (!stateDirectory.existsSync()) return null;
    final dir = Directory(
      '${stateDirectory.path}/pre-restore-${_stamp(_clock())}',
    );
    await dir.create(recursive: true);
    await for (final e in stateDirectory.list(followLinks: false)) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (name.startsWith('pre-restore-')) continue;
      if (!_keepSuffixes.any(name.endsWith)) continue;
      await e.copy('${dir.path}/$name');
    }
    return dir;
  }

  static bool _parses(String name, String body) {
    if (name.endsWith('.jsonl')) {
      for (final line in const LineSplitter().convert(body)) {
        if (line.trim().isEmpty) continue;
        try {
          jsonDecode(line);
        } on FormatException {
          return false;
        }
      }
      return true;
    }
    try {
      jsonDecode(body);
      return true;
    } on FormatException {
      return false;
    }
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
