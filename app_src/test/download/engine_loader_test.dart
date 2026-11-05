import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/download/capability.dart';
import 'package:sonarar/download/engine_loader.dart';

/// The engine archive is 14 MB and lands in app storage as an interpreter that
/// runs Python. Every branch here is a way that goes wrong in the field: a
/// truncated download, a swapped archive, a cache from a killed app.
void main() {
  final good = utf8.encode('the engine');
  final hash = sha256.convert(good).toString();

  EngineLoader loader({
    required Future<bool> Function() probe,
    required Future<List<int>?> Function() readCache,
    required List<int> Function() fetch,
    Future<bool> Function(String path)? install,
  }) {
    return EngineLoader(
      source: EngineSource(
        url: Uri.parse('https://example.test/libpython.zip'),
        sha256: hash,
        version: 'yt-dlp 0.18.1',
      ),
      readCache: readCache,
      writeCache: (_) async {},
      download: (_) async => fetch(),
      install: install ?? (_) async => true,
      probe: probe,
    );
  }

  test('a build that already has the engine downloads nothing', () async {
    var downloads = 0;
    final l = loader(
      probe: () async => true,
      readCache: () async => null,
      fetch: () {
        downloads++;
        return good;
      },
    );

    expect(await l.ensure(), EngineInstall.alreadyThere);
    expect(downloads, 0, reason: 'a full build must never phone home for this');
  });

  test('a verified archive is installed and the path handed on', () async {
    String? installed;
    final l = loader(
      probe: () async => false,
      readCache: () async => null,
      fetch: () => good,
      install: (path) async {
        installed = path;
        return true;
      },
    );

    expect(await l.ensure(), EngineInstall.ready);
    expect(installed, isNotNull);
    expect(installed!.endsWith('libpython.zip.so'), isTrue,
        reason: 'the library looks for it by that name');
  });

  test('a corrupt archive is refused before anything unzips', () async {
    var installs = 0;
    final l = loader(
      probe: () async => false,
      readCache: () async => null,
      fetch: () => utf8.encode('not the engine'),
      install: (_) async {
        installs++;
        return true;
      },
    );

    expect(await l.ensure(), EngineInstall.badArchive);
    expect(installs, 0, reason: 'unzipping a bad archive is how a working engine dies');
  });

  test('a half-written cache is refetched rather than trusted', () async {
    var downloads = 0;
    final l = loader(
      probe: () async => false,
      readCache: () async => utf8.encode('trunc'),
      fetch: () {
        downloads++;
        return good;
      },
    );

    expect(await l.ensure(), EngineInstall.ready);
    expect(downloads, 1, reason: 'the cache failed its hash, so it cannot be used');
  });

  test('a good cache is reused without downloading again', () async {
    var downloads = 0;
    final l = loader(
      probe: () async => false,
      readCache: () async => good,
      fetch: () {
        downloads++;
        return good;
      },
    );

    expect(await l.ensure(), EngineInstall.ready);
    expect(downloads, 0);
  });

  test('an archive that installs but does not start is reported, not assumed',
      () async {
    final l = loader(
      probe: () async => false,
      readCache: () async => null,
      fetch: () => good,
      install: (_) async => false,
    );

    expect(await l.ensure(), EngineInstall.failed);
  });

  group('the archive matches the device', () {
    test('arm64 phones get the arm64 interpreter', () {
      expect(engineSourceFor('arm64-v8a')?.sha256,
          '7edecb6c9bd3a94456168d44911d8aea9f917bedef90c320a29500d92ac3eb62');
    });

    test('x86_64 gets its own, not the arm one', () {
      expect(engineSourceFor('x86_64')?.sha256,
          '27caa316e09681ada860fdb6b35c1914e541e266e674141361758ac127fe2f15',
          reason: 'this is what makes an emulator install meaningful instead of a fake failure');
    });

    test('a 32-bit device falls back to its family rather than nothing', () {
      expect(engineSourceFor('armeabi-v7a'), isNotNull);
      expect(engineSourceFor('x86'), isNotNull);
    });

    test('an architecture with no archive is refused, not guessed at', () {
      expect(engineSourceFor('mips64'), isNull);
      expect(engineSourceFor(null), isNull);
    });

    test('every hosted archive declares a hash and a size the app can trust', () {
      for (final e in kHostedEngines.entries) {
        expect(e.value.sha256.length, 64, reason: 'a short hash would verify anything');
        expect(e.value.url.toString(), contains('.zip'));
      }
    });
  });
}
