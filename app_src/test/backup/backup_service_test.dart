import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/backup/backup_service.dart';

void main() {
  late Directory state;
  late Directory downloads;

  setUp(() {
    state = Directory.systemTemp.createTempSync('sonarar-state-');
    downloads = Directory.systemTemp.createTempSync('sonarar-dl-');
  });

  tearDown(() {
    if (state.existsSync()) state.deleteSync(recursive: true);
    if (downloads.existsSync()) downloads.deleteSync(recursive: true);
  });

  void seedState() {
    File('${state.path}/prefs.json')
        .writeAsStringSync(jsonEncode({'volume': 0.8}));
    File('${state.path}/playlists.json')
        .writeAsStringSync(jsonEncode({'items': []}));
    File('${state.path}/plays.jsonl').writeAsStringSync(
      '${jsonEncode({'id': 'a'})}\n${jsonEncode({'id': 'b'})}\n',
    );
    // Not ours: a note the user dropped in the folder must not travel.
    File('${state.path}/notes.txt').writeAsStringSync('hello');
  }

  test('a backup carries the state files and nothing else', () async {
    seedState();
    final report = await BackupService(stateDirectory: state)
        .writeTo(downloads, appVersion: '0.2.0+20');

    expect(report.ok, isTrue);
    final payload =
        jsonDecode(report.file!.readAsStringSync()) as Map<String, dynamic>;
    expect(payload['format'], kBackupFormat);
    expect(payload['app'], '0.2.0+20');
    final files = payload['files'] as Map<String, dynamic>;
    expect(files.keys, containsAll(['prefs.json', 'playlists.json', 'plays.jsonl']));
    expect(files.containsKey('notes.txt'), isFalse);
  });

  test('restore writes the files back and keeps the current state aside',
      () async {
    seedState();
    final service = BackupService(stateDirectory: state);
    final backup = await service.writeTo(downloads);

    // The user loses their likes after the backup.
    File('${state.path}/prefs.json').writeAsStringSync(jsonEncode({'volume': 0}));

    final report = await service.restore(backup.file!);
    expect(report.ok, isTrue);
    expect(report.files, 3);
    expect(
      jsonDecode(File('${state.path}/prefs.json').readAsStringSync())['volume'],
      0.8,
    );
    expect(report.savedCurrentTo, isNotNull);
    final aside = Directory(report.savedCurrentTo!.path);
    expect(aside.listSync().whereType<File>(), isNotEmpty);
    expect(
      jsonDecode(File('${aside.path}/prefs.json').readAsStringSync())['volume'],
      0,
    );
  });

  test('a file that is not a backup is refused, not written', () async {
    seedState();
    final foreign = File('${downloads.path}/sonarar-backup-20300101-000000.json')
      ..writeAsStringSync(jsonEncode({'hello': 'world'}));
    final before = File('${state.path}/prefs.json').readAsStringSync();

    final report = await BackupService(stateDirectory: state).restore(foreign);
    expect(report.ok, isFalse);
    expect(report.error, contains('not a Sonarar backup'));
    expect(File('${state.path}/prefs.json').readAsStringSync(), before);
  });

  test('a backup cannot write outside the state folder', () async {
    seedState();
    final hostile = File('${downloads.path}/sonarar-backup-20300102-000000.json')
      ..writeAsStringSync(jsonEncode({
        'format': kBackupFormat,
        'version': 1,
        'files': {'../escape.json': '{"x":1}', 'prefs.json': '{"volume":0.1}'},
      }));

    final report = await BackupService(stateDirectory: state).restore(hostile);
    expect(report.ok, isTrue);
    expect(report.skipped, contains('../escape.json'));
    expect(File('${state.path}/../escape.json').existsSync(), isFalse);
  });

  test('a backup from a newer format is refused', () async {
    final newer = File('${downloads.path}/sonarar-backup-20300103-000000.json')
      ..writeAsStringSync(jsonEncode({
        'format': kBackupFormat,
        'version': kBackupVersion + 1,
        'files': {'prefs.json': '{}'},
      }));
    final report = await BackupService(stateDirectory: state).restore(newer);
    expect(report.ok, isFalse);
    expect(report.error, contains('newer version'));
  });

  test('an empty state folder makes no backup rather than an empty one',
      () async {
    final report = await BackupService(stateDirectory: state).writeTo(downloads);
    expect(report.ok, isFalse);
    expect(report.error, contains('no state'));
  });

  test('backups are listed newest first and filtered by name', () async {
    File('${downloads.path}/sonarar-backup-20290101-101010.json')
        .writeAsStringSync('{}');
    File('${downloads.path}/sonarar-backup-20290601-101010.json')
        .writeAsStringSync('{}');
    File('${downloads.path}/holiday.jpg').writeAsStringSync('');

    final found = BackupService.findBackups(downloads);
    expect(found.length, 2);
    expect(
      found.first.uri.pathSegments.last,
      'sonarar-backup-20290601-101010.json',
    );
  });
}
