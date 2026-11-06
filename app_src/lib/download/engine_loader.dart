library;

import 'dart:io';

import 'package:crypto/crypto.dart';

/// Where the engine archive comes from, and what it must hash to.
class EngineSource {
  const EngineSource({
    required this.url,
    required this.sha256,
    required this.version,
  });

  final Uri url;

  /// The archive is 14 MB of interpreter; a truncated or swapped download must
  /// never reach the unzipper.
  final String sha256;

  /// Shown to the user: "one-time 14 MB download (yt-dlp 0.18.1)".
  final String version;
}

/// What happened, in the terms the UI needs.
enum EngineInstall { ready, alreadyThere, badArchive, failed }

/// Fetches the download engine once and installs it.
///
/// Every effect is injected — download, hash, install — so the whole decision
/// table is testable without a device, a network or a 14 MB fixture.
class EngineLoader {
  EngineLoader({
    required this.source,
    required this.readCache,
    required this.writeCache,
    required this.download,
    required this.install,
    required this.probe,
    this.onProgress,
    this.retriesOnMismatch = 1,
  });

  final EngineSource source;

  /// Bytes already downloaded, if a previous attempt got that far.
  final Future<List<int>?> Function() readCache;
  final Future<void> Function(List<int> bytes) writeCache;

  /// Fetch the archive. [onProgress] is byte-accurate where the transport allows.
  final Future<List<int>> Function(Uri url) download;

  /// Hand a path to the plugin; true when the engine came up.
  final Future<bool> Function(String zipPath) install;

  /// Is the engine already there (a full build, or a previous install)?
  final Future<bool> Function() probe;

  final void Function(double fraction)? onProgress;

  /// How many extra downloads a checksum mismatch is worth. A reset connection hands
  /// back half an archive; the checksum is the only thing that notices, and telling
  /// the person "it failed" for a carrier hiccup is a poor answer.
  final int retriesOnMismatch;

  Future<EngineInstall> ensure() async {
    if (await probe()) return EngineInstall.alreadyThere;

    final cached = await readCache();
    var payload =
        cached != null && sha256.convert(cached).toString() == source.sha256
        // A half-written cache from a killed download is refetched rather than unzipped.
        ? cached
        : await download(source.url);

    var attempts = 0;
    while (sha256.convert(payload).toString() != source.sha256) {
      if (attempts++ >= retriesOnMismatch) {
        await writeCache(payload);
        return EngineInstall.badArchive;
      }
      // A reset connection hands back half an archive, and the checksum is the only
      // thing that notices. One more read over a fresh connection is cheap.
      payload = await download(source.url);
    }
    await writeCache(payload);

    final dir = await Directory.systemTemp.createTemp('sonarar_engine');
    final file = File('${dir.path}/libpython.zip.so');
    try {
      await file.writeAsBytes(payload, flush: true);
      final ok = await install(file.path);
      return ok ? EngineInstall.ready : EngineInstall.failed;
    } finally {
      if (await dir.exists()) {
        try {
          await dir.delete(recursive: true);
        } on FileSystemException {
          // The install already copied what it needs; a leftover temp dir is not
          // worth failing an install that worked.
        }
      }
    }
  }
}
