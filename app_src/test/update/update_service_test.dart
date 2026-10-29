import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarar/core/build_info.dart';
import 'package:sonarar/update/update_service.dart';

/// The update check is only allowed to speak when it has something true to say.
void main() {
  Map<String, Object?> release({String tag = 'v0.2.2', String name = '0.2.2+22'}) => {
        'tag_name': tag,
        'name': name,
        'html_url': 'https://example.test/release',
        'assets': [
          {
            'name': 'Sonarar-0.2.2-arm64.apk',
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
    expect(update!.version, '0.2.2');
    expect(update.build, 22);
    expect(update.apkUrl, 'https://example.test/app.apk');
  });

  test('a release title without a build number is still noticed', () async {
    // The 0.2.1 release is titled "Sonarar 0.2.1 — Personalize": no +21. A check
    // that requires one would never fire on this repo's own releases.
    final update = await checkForUpdate(
      appVersionCode,
      currentVersion: appVersionName,
      client: clientReturning(release(
        tag: 'v0.2.2',
        name: 'Sonarar 0.2.2 Personalize',
      )),
    );

    expect(update?.version, '0.2.2');
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
        client: clientReturning(release(name: '0.2.0+$appVersionCode')));

    expect(update, isNull, reason: 'the app offered itself as an update');
  });

  test('an older release is not offered', () async {
    final update = await checkForUpdate(appVersionCode,
        client: clientReturning(release(tag: 'v0.1.3', name: '0.1.3+19')));

    expect(update, isNull);
  });

  test('a release with no APK is ignored, not half-offered', () async {
    final update = await checkForUpdate(appVersionCode, client: clientReturning({
      'tag_name': 'v0.2.2',
      'name': '0.2.2+22',
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
      'tag_name': 'v0.2.2',
      'name': '0.2.2+22',
      'assets': [
        {
          'name': 'Sonarar-0.2.2-universal.apk',
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

  test('F-Droid builds turn the whole thing off', () {
    // Compile-time switch: this test documents the contract, and the F-Droid
    // build passes --dart-define=SONARAR_SELF_UPDATE=false.
    expect(kSelfUpdate, isTrue,
        reason: 'this build is allowed to look; if it is not, the bar is dead '
            'code and the flag reached the wrong place');
  });
}
