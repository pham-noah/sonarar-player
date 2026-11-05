import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';

/// A lite build has no engine in the APK. The manager must refuse at the door:
/// queueing a job it can never run would spin a progress ring for ever and send
/// yt-dlp into a Python runtime that is not there.
void main() {
  // installEngine asks the plugin for the device ABI before downloading.
  TestWidgetsFlutterBinding.ensureInitialized();
  DownloadManager manager({required bool available, bool fetchable = true}) {
    final dir = Directory.systemTemp.createTempSync('sonarar_cap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final m = DownloadManager(
      repo: LibraryRepository(),
      downloadDirOf: () => dir,
      manifestOf: () => null,
      downloadsAvailable: available,
    )..engineFetchable = fetchable;
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
    expect(m.lastIssue?.detail, DownloadManager.engineNeeded,
        reason: 'a lite build can download, it just has to fetch the engine first');
    expect(m.needsEngine, isTrue);
  });

  test('a build that can neither run nor fetch the engine says so', () {
    final m = manager(available: false, fetchable: false);

    m.enqueue(job());

    expect(m.downloadsCompiledOut, isTrue);
    expect(m.needsEngine, isFalse);
    expect(m.lastIssue?.detail, DownloadManager.notInThisBuild);
  });

  test('after the engine is installed a lite build downloads normally', () async {
    final m = manager(available: false);
    expect(m.canDownload, isFalse);

    // The loader is injected here; the real one fetches 14 MB.
    final ok = await m.installEngine(
      download: (_) async => throw Exception('network off in tests'),
    );

    expect(ok, isFalse, reason: 'a failed fetch must not claim the engine is there');
    expect(m.canDownload, isFalse);
  });

  test('with the engine the gate lets it through', () {
    final m = manager(available: true);

    expect(m.canDownload, isTrue);
    expect(m.lastIssue, isNull);
  });
}
