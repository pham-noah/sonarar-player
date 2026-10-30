import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarar/core/build_info.dart';
import 'package:sonarar/update/update_service.dart';

/// The update check is only allowed to speak when it has something true to say.
void main() {
  // Fixtures are described relative to the version this build says it is, so
  // bumping the app does not turn them into "no longer newer" and redden the
  // suite — which is exactly what happened to the 0.2.2 build.
  const newerTag = 'v9.9.9';
  final newerBuild = appVersionCode + 1;

  Map<String, Object?> release({String tag = newerTag, String? name}) => {
        'tag_name': tag,
        'name': name ?? '9.9.9+$newerBuild',
        'html_url': 'https://example.test/release',
        'assets': [
          {
            'name': 'Sonarar-9.9.9-arm64.apk',
            'browser_download_url': 'https://example.test/app.apk',
            'size': 1000,
          },
        ],
      };

  http.Client clientReturning(Object? body, {int code = 200}) => MockClient(
        (_) async => http.Response(jsonEncode(body), code),
      );

  test('a newer build is offered', () async {
    final update = await checkForUpdate(appVersionCode,
        client: clientReturning(release()));

    expect(update, isNotNull);
    expect(update!.version, '9.9.9');
    expect(update.build, newerBuild);
    expect(update.apkUrl, 'https://example.test/app.apk');
  });

  test('a release title without a build number is still noticed', () async {
    // The 0.2.1 release is titled "Sonarar 0.2.1 — Personalize": no +21. A check
    // that requires one would never fire on this repo's own releases.
    final update = await checkForUpdate(
      appVersionCode,
      currentVersion: appVersionName,
      client: clientReturning(release(
        tag: newerTag,
        name: 'Sonarar 9.9.9 Personalize',
      )),
    );

    expect(update?.version, '9.9.9');
  });

  test('a release title without a build is not offered when it is the same version',
      () async {
    final update = await checkForUpdate(
      appVersionCode,
      currentVersion: appVersionName,
      client: clientReturning(release(
        tag: 'v$appVersionName',
        name: 'Sonarar $appVersionName Personalize',
      )),
    );

    expect(update, isNull);
  });

  test('the same build is not offered again', () async {
    final update = await checkForUpdate(appVersionCode,
        client: clientReturning(release(name: '$appVersionName+$appVersionCode')));

    expect(update, isNull, reason: 'the app offered itself as an update');
  });

  test('an older release is not offered', () async {
    final update = await checkForUpdate(appVersionCode,
        client: clientReturning(release(tag: 'v0.1.3', name: '0.1.3+19')));

    expect(update, isNull);
  });

  test('a release with no APK is ignored, not half-offered', () async {
    final update = await checkForUpdate(appVersionCode, client: clientReturning({
      'tag_name': newerTag,
      'name': '9.9.9+$newerBuild',
      'assets': [
        {'name': 'notes.txt', 'browser_download_url': 'https://example.test/n.txt'},
      ],
    }));

    expect(update, isNull);
  });

  test('a failing API is silence, not a crash', () async {
    expect(
      await checkForUpdate(appVersionCode,
          client: clientReturning({'message': 'rate limited'}, code: 403)),
      isNull,
    );
    expect(
      await checkForUpdate(appVersionCode,
          client: MockClient((_) async => throw const SocketException('offline'))),
      isNull,
    );
  });

  test('the arm64 APK is chosen when a release carries several', () async {
    final update = await checkForUpdate(appVersionCode, client: clientReturning({
      'tag_name': newerTag,
      'name': '9.9.9+$newerBuild',
      'assets': [
        {
          'name': 'Sonarar-9.9.9-universal.apk',
          'browser_download_url': 'https://example.test/universal.apk',
          'size': 2000,
        },
        {
          'name': 'Sonarar-0.2.2-arm64.apk',
          'browser_download_url': 'https://example.test/arm64.apk',
          'size': 1000,
        },
      ],
    }));

    expect(update?.apkUrl, 'https://example.test/arm64.apk');
  });

  test('a download that ends short is discarded, not handed to the installer',
      () async {
    final dir = Directory.systemTemp.createTempSync('sonarar-update');
    addTearDown(() => dir.deleteSync(recursive: true));

    final file = await downloadUpdate(
      const AppUpdate(
        version: '0.2.2',
        build: 22,
        apkUrl: 'https://example.test/app.apk',
        notesUrl: '',
        sizeBytes: 2000,
      ),
      dir,
      client: MockClient.streaming((_, __) async => http.StreamedResponse(
            Stream.value(utf8.encode('too short')),
            200,
            contentLength: 2000,
          )),
    );

    expect(file, isNull, reason: 'a partial APK would fail to install');
    expect(dir.listSync(), isEmpty, reason: 'the partial file was left behind');
  });

  test('build_info agrees with pubspec, or the update check compares nonsense',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final line = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);
    expect(line, '$appVersionName+$appVersionCode');
  });

  test('a title without a build still compares versions', () async {
    // The release title carries no `+NN`: the tag has to do the work, and it
    // can only do it if the app says which version it is. A caller that passes
    // neither would silently never see this release.
    final release = <String, Object?>{
      'tag_name': 'v9.9.10',
      'name': 'Sonarar 9.9.10',
      'html_url': 'https://example.test/release',
      'assets': [
        {
          'name': 'Sonarar-9.9.10-arm64.apk',
          'browser_download_url': 'https://example.test/a.apk',
          'size': 1024,
        },
      ],
    };

    final newer = await checkForUpdate(appVersionCode,
        client: clientReturning(release));
    expect(newer?.version, '9.9.10');

    final same = await checkForUpdate(
      appVersionCode,
      currentVersion: '9.9.10',
      client: clientReturning(release),
    );
    expect(same, isNull, reason: 'the build we are on is not an update');
  });

  test('F-Droid builds turn the whole thing off', () {
    // Compile-time switch: this test documents the contract, and the F-Droid
    // build passes --dart-define=SONARAR_SELF_UPDATE=false.
    expect(kSelfUpdate, isTrue,
        reason: 'this build is allowed to look; if it is not, the bar is dead '
            'code and the flag reached the wrong place');
  });

  group('the APK is held to the digest the release publishes', () {
    Future<Directory> tmp() =>
        Directory.systemTemp.createTemp('sonarar-update-test');

    test('a digest in the notes is read off the release', () async {
      final client = MockClient((r) async => http.Response(
            jsonEncode({
              'tag_name': 'v0.2.1',
              'name': '0.2.1+21',
              'html_url': 'x',
              'body': 'Notes.\nsha256: '
                  '${'a' * 64}',
              'assets': [
                {
                  'name': 'Sonarar-0.2.1-arm64.apk',
                  'browser_download_url': 'https://example.com/a.apk',
                  'size': 10,
                }
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final update = await checkForUpdate(20, client: client);
      expect(update!.sha256, 'a' * 64);
    });

    test('a file that does not match is DELETED, not handed to the installer',
        () async {
      final dir = await tmp();
      addTearDown(() => dir.delete(recursive: true));
      final client = MockClient((r) async => http.Response.bytes(
            utf8.encode('not the real apk'),
            200,
            headers: {'content-length': '16'},
          ));
      final update = AppUpdate(
        version: '0.2.1',
        build: 21,
        apkUrl: 'https://example.com/a.apk',
        notesUrl: '',
        sizeBytes: 16,
        sha256: 'f' * 64,
      );
      final file = await downloadUpdate(update, dir, client: client);
      expect(file, isNull);
      expect(
        dir.listSync().whereType<File>().length,
        0,
        reason: 'a rejected download must not sit in Downloads',
      );
    });

    test('a file that does match is kept', () async {
      final dir = await tmp();
      addTearDown(() => dir.delete(recursive: true));
      const body = 'a real apk';
      final digest = sha256.convert(utf8.encode(body)).toString();
      final client = MockClient((r) async => http.Response.bytes(
            utf8.encode(body),
            200,
            headers: {'content-length': '${body.length}'},
          ));
      final update = AppUpdate(
        version: '0.2.1',
        build: 21,
        apkUrl: 'https://example.com/a.apk',
        notesUrl: '',
        sizeBytes: body.length,
        sha256: digest,
      );
      final file = await downloadUpdate(update, dir, client: client);
      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
    });
  });
}
