library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/download/download_manager.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:ytdlp_flutter/ytdlp_flutter.dart';

/// The engine an update should not throw away.
///
/// A lite build unpacks the interpreter into `noBackupFilesDir` and records that
/// it did in SharedPreferences; both survive an app update. The app kept that
/// answer in memory only, so every cold start - and so every update - offered the
/// same "set up downloads" download that was already installed.
DownloadManager _manager({
  Future<YtdlpCapabilities> Function()? capabilities,
  bool downloadsAvailable = false,
}) =>
    DownloadManager(
      repo: LibraryRepository(),
      downloadDirOf: () => Directory.systemTemp,
      manifestOf: () => File('${Directory.systemTemp.path}/manifest.json'),
      downloadsAvailable: downloadsAvailable,
      capabilitiesOf: capabilities,
    );

YtdlpCapabilities _caps({required bool engine}) => YtdlpCapabilities(
      engine: engine,
      engineError: engine ? null : 'no engine',
      abi: 'arm64-v8a',
    );

Future<List<int>> _noDownload(Uri url) async => throw StateError(
      'the archive should not have been fetched',
    );

void main() {
  test('a probe that finds the engine makes downloads usable, no install',
      () async {
    final manager = _manager(capabilities: () async => _caps(engine: true));

    expect(manager.canDownload, isFalse, reason: 'nothing has asked yet');
    expect(manager.needsEngine, isTrue, reason: 'the setup banner would be up');

    await manager.probeEngine();

    expect(manager.canDownload, isTrue);
    expect(manager.needsEngine, isFalse,
        reason: 'no setup offer after an update');
    expect(manager.checkingEngine, isFalse, reason: 'the wait is over');
  });

  test('a probe that finds nothing leaves the offer up', () async {
    final manager = _manager(capabilities: () async => _caps(engine: false));

    await manager.probeEngine();

    expect(manager.canDownload, isFalse);
    expect(manager.needsEngine, isTrue);
  });

  test('a probe that cannot answer is not an answer', () async {
    final manager = _manager(
      capabilities: () async => throw const SocketException('no plugin'),
    );

    await manager.probeEngine().timeout(const Duration(seconds: 5));

    expect(manager.checkingEngine, isFalse, reason: 'nothing is left spinning');
    expect(manager.canDownload, isFalse);
  });

  test('install asks the device before it spends the download', () async {
    final manager = _manager(capabilities: () async => _caps(engine: true));

    expect(await manager.installEngine(download: _noDownload), isTrue);
    expect(manager.canDownload, isTrue);
  });

  test('a full build never probes', () async {
    var probes = 0;
    final manager = _manager(
      downloadsAvailable: true,
      capabilities: () async {
        probes++;
        return _caps(engine: true);
      },
    );

    await manager.probeEngine();

    expect(probes, 0);
    expect(manager.canDownload, isTrue);
  });

  test('one probe per run, however many screens ask', () async {
    var probes = 0;
    final manager = _manager(
      capabilities: () async {
        probes++;
        return _caps(engine: true);
      },
    );

    await manager.probeEngine();
    await manager.probeEngine();

    expect(probes, 1);
  });
}
