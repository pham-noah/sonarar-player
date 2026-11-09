// Hostile release-channel QA. GitHub is the one place Sonarar trusts a remote
// document, so its shape is attacked here: wrong types, missing fields, several
// digests, prereleases, and a tag that is not a version.
@Tags(['adversarial'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarar/update/update_service.dart';

http.Client jsonClient(Object? body, {int code = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(body), code));

Map<String, Object?> release({
  String tag = 'v9.9.9',
  Object? name = '9.9.9+999999',
  Object? assets,
  Object? body,
}) =>
    {
      'tag_name': tag,
      'name': name,
      'html_url': 'https://example.test/r',
      'body': body,
      'assets': assets ??
          [
            {
              'name': 'Sonarar-9.9.9-arm64.apk',
              'browser_download_url': 'https://example.test/a.apk',
              'size': 10,
            }
          ],
    };

void main() {
  group('the release document cannot be made to crash the check', () {
    test('a JSON array instead of an object is ignored', () async {
      expect(await checkForUpdate(1, client: jsonClient([1, 2, 3])), isNull);
    });

    test('a null body is ignored', () async {
      expect(
        await checkForUpdate(1,
            client: MockClient((_) async => http.Response('null', 200))),
        isNull,
      );
    });

    test('assets of the wrong shape are ignored, not fatal', () async {
      final update = await checkForUpdate(
        1,
        client: jsonClient(release(assets: [
          42,
          'nope',
          {'name': 5, 'browser_download_url': 'https://example.test/x.apk'},
          {'name': 'x.apk'},
          {
            'name': 'Sonarar-9.9.9-arm64.apk',
            'browser_download_url': 'https://example.test/ok.apk',
            'size': 'twelve',
          },
        ])),
      );
      expect(update?.apkUrl, 'https://example.test/ok.apk');
      expect(update?.sizeBytes, 0, reason: 'a non-numeric size is 0, not a crash');
    });

    test('a build number too large for an int is silence, not a throw', () async {
      await expectLater(
        checkForUpdate(1, client: jsonClient(release(name: '9.9.9+99999999999999999999'))),
        completion(isNull),
      );
    });

    test('a body that is a number is not read as release notes', () async {
      final update = await checkForUpdate(1, client: jsonClient(release(body: 12)));
      expect(update?.notes, '');
    });
  });

  group('the right APK and the right digest', () {
    final lite = 'a' * 64;
    final full = 'b' * 64;

    Map<String, Object?> both() => release(
          body: 'Lite\nsha256: $lite\n\nFull\nsha256: $full',
          assets: [
            {
              'name': 'Sonarar-9.9.9-arm64-lite.apk',
              'browser_download_url': 'https://example.test/lite.apk',
              'size': 10,
            },
            {
              'name': 'Sonarar-9.9.9-arm64-full.apk',
              'browser_download_url': 'https://example.test/full.apk',
              'size': 20,
            },
          ],
        );

    test('the lite build is offered to a build that fetches its engine', () async {
      final u = await checkForUpdate(1, engineBundled: false, client: jsonClient(both()));
      expect(u!.apkUrl, 'https://example.test/lite.apk');
      expect(u.sha256, lite);
    });

    test('the full build is offered to a build that carries its engine', () async {
      final u = await checkForUpdate(1, engineBundled: true, client: jsonClient(both()));
      expect(u!.apkUrl, 'https://example.test/full.apk');
      expect(
        u.sha256,
        full,
        reason: 'the digest read from the notes belongs to whichever APK is '
            'offered; the first digest in the body is the lite one',
      );
    });

    test('uppercase hex is normalised to the sha256 the file will hash to', () async {
      final u = await checkForUpdate(1,
          client: jsonClient(release(body: 'sha256: ${'A' * 64}')));
      expect(u?.sha256, 'a' * 64);
    });

    test('a digest one character short is not published as a digest', () async {
      final u = await checkForUpdate(1,
          client: jsonClient(release(body: 'sha256: ${'a' * 63}')));
      expect(u?.sha256, isNull);
    });

    test('a prerelease tag is not installed over a stable build by itself',
        () async {
      final u = await checkForUpdate(1, client: jsonClient(release(
            tag: 'v9.9.9-beta.1',
            name: 'Sonarar beta',
          )));
      expect(u, isNull,
          reason: 'an unmarked beta on the latest endpoint must not self-install');
    });

    test('two digests with no asset hint are not guessed at', () async {
      final u = await checkForUpdate(
        1,
        engineBundled: true,
        client: jsonClient(release(
          body: 'sha256: ${'a' * 64}\nsha256: ${'b' * 64}',
          assets: [
            {
              'name': 'Sonarar-9.9.9-arm64.apk',
              'browser_download_url': 'https://example.test/a.apk',
              'size': 10,
            },
          ],
        )),
      );
      expect(u?.sha256, isNull,
          reason: 'a wrong digest deletes the download and never updates');
    });
  });

  group('the download obeys its size and digest', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('sonarar-dl'));
    tearDown(() => dir.deleteSync(recursive: true));

    AppUpdate updateFor(String version, {String? sha, int size = 16}) => AppUpdate(
          version: version,
          build: 1,
          apkUrl: 'https://example.test/a.apk',
          notesUrl: '',
          sizeBytes: size,
          sha256: sha,
        );

    test('a version that is not a filename cannot escape the Downloads folder',
        () async {
      const body = 'a real apk';
      final digest = sha256.convert(utf8.encode(body)).toString();
      final file = await downloadUpdate(
        updateFor('../escaped', sha: digest),
        dir,
        client: MockClient((_) async => http.Response(body, 200)),
      );
      final outside = File('${dir.parent.path}/escaped.apk');
      expect(outside.existsSync(), isFalse,
          reason: 'wrote ${file?.path ?? outside.path} outside Downloads');
    });
  });
}
