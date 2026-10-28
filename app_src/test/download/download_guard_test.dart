import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';

void main() {
  test('a folder that cannot be written reports an error the UI can show',
      () async {
    final tmp = await Directory.systemTemp.createTemp('sonarar_dl');
    addTearDown(() => tmp.deleteSync(recursive: true));

    // A file wearing the folder's name: creating the directory must fail,
    // which is the same shape as Android refusing the write without the
    // all-files grant.
    final blocker = File('${tmp.path}${Platform.pathSeparator}Downloaded')
      ..writeAsStringSync('not a folder');

    final manager = DownloadManager(
      repo: LibraryRepository(),
      downloadDirOf: () => Directory(blocker.path),
      manifestOf: () => null,
    );
    addTearDown(manager.dispose);

    manager.enqueue(DownloadJob(videoId: 'abc123', title: 'a track'));

    // The queue runs on its own microtask chain; wait for it to settle.
    for (var i = 0; i < 40 && manager.lastError == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }

    expect(manager.lastError, isNotNull);
    expect(manager.lastError, contains('All files access'));

    manager.clearError();
    expect(manager.lastError, isNull);
  });
}
