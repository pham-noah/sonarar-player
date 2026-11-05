import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';

/// A lite build has no engine in the APK. The manager must refuse at the door:
/// queueing a job it can never run would spin a progress ring for ever and send
/// yt-dlp into a Python runtime that is not there.
void main() {
  DownloadManager manager({required bool available}) {
    final dir = Directory.systemTemp.createTempSync('sonarar_cap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final m = DownloadManager(
      repo: LibraryRepository(),
      downloadDirOf: () => dir,
      manifestOf: () => null,
      downloadsAvailable: available,
    );
    addTearDown(m.dispose);
    return m;
  }

  DownloadJob job() =>
      DownloadJob(videoId: 'jNQXAC9IVRw', title: 't', channel: 'c');

  test('without the engine the job is refused, not queued', () {
    final m = manager(available: false);

    m.enqueue(job());

    expect(m.canDownload, isFalse);
    expect(m.contains('jNQXAC9IVRw'), isFalse, reason: 'a queued job would never move');
    expect(m.lastIssue?.detail, DownloadManager.notInThisBuild,
        reason: 'the row has to say why, not just stop');
  });

  test('with the engine the gate lets it through', () {
    final m = manager(available: true);

    expect(m.canDownload, isTrue);
    expect(m.lastIssue, isNull);
  });
}
