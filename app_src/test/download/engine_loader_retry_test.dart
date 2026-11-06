library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/download/engine_loader.dart';

/// The retry that turns a carrier hiccup into a working engine.
///
/// A reset connection hands back half an archive. The checksum is the only thing that
/// notices — the previous code returned "the fetch failed" and the person was left
/// with a button that did nothing.
List<int> _zip(List<int> bytes) => bytes;

void main() {
  late List<int> good;
  late String goodSha;

  setUp(() {
    good = utf8.encode('the engine archive, all fourteen megabytes of it');
    goodSha = sha256.convert(good).toString();
  });

  EngineSource source() => EngineSource(
        url: Uri.parse('https://example.invalid/engine.zip'),
        sha256: goodSha,
        version: 'test',
      );

  EngineLoader loader({
    required Future<List<int>> Function(Uri) download,
    Future<bool> Function(String)? install,
    int retries = 1,
  }) =>
      EngineLoader(
        source: source(),
        readCache: () async => null,
        writeCache: (_) async {},
        download: download,
        install: install ?? (_) async => true,
        probe: () async => false,
        retriesOnMismatch: retries,
      );

  group('a truncated download', () {
    test('is retried once, and the second read installs', () async {
      var calls = 0;
      final result = await loader(
        download: (_) async {
          calls++;
          return calls == 1 ? good.sublist(0, 10) : _zip(good);
        },
      ).ensure();

      expect(result, EngineInstall.ready,
          reason: 'a half-read archive is a retry, not a verdict');
      expect(calls, 2, reason: 'one refetch, not a loop');
    });

    test('twice in a row is a bad archive, said as such', () async {
      var calls = 0;
      final result = await loader(
        download: (_) async {
          calls++;
          return good.sublist(0, 10);
        },
      ).ensure();

      expect(result, EngineInstall.badArchive);
      expect(calls, 2, reason: 'one retry, then the truth');
    });

    test('with retries turned off, one read decides', () async {
      var calls = 0;
      final result = await loader(
        retries: 0,
        download: (_) async {
          calls++;
          return good.sublist(0, 10);
        },
      ).ensure();

      expect(result, EngineInstall.badArchive);
      expect(calls, 1);
    });
  });

  group('what still works', () {
    test('a good first read installs, with no second call', () async {
      var calls = 0;
      final result = await loader(
        download: (_) async {
          calls++;
          return _zip(good);
        },
      ).ensure();

      expect(result, EngineInstall.ready);
      expect(calls, 1);
    });

    test('an engine already in place is not fetched at all', () async {
      var calls = 0;
      final loaderWithEngine = EngineLoader(
        source: source(),
        readCache: () async => null,
        writeCache: (_) async {},
        download: (_) async {
          calls++;
          return _zip(good);
        },
        install: (_) async => true,
        probe: () async => true,
      );

      expect(await loaderWithEngine.ensure(), EngineInstall.alreadyThere);
      expect(calls, 0);
    });

    test('an archive that will not install is reported, not retried', () async {
      var calls = 0;
      final result = await loader(
        download: (_) async {
          calls++;
          return _zip(good);
        },
        install: (_) async => false,
      ).ensure();

      expect(result, EngineInstall.failed);
      expect(calls, 1, reason: 'the bytes were right; the install was not');
    });
  });
}
