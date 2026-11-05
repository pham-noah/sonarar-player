import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sonarar/update/update_service.dart';

/// Two builds ship from one release. Handing a lite install the full APK would
/// reinstall the 14 MB engine the user deliberately avoided.
void main() {
  Map<String, Object?> release(List<String> apks) => {
        'tag_name': 'v0.3.3',
        'name': '0.3.3',
        'body': 'notes',
        'assets': [
          for (final name in apks)
            {
              'name': name,
              'browser_download_url': 'https://example.test/$name',
              'size': 1024,
            },
        ],
      };

  Future<AppUpdate?> check(List<String> apks, {bool? engineBundled}) {
    final client = MockClient((_) async => http.Response(jsonEncode(release(apks)), 200));
    return checkForUpdate(32,
        currentVersion: '0.3.2', engineBundled: engineBundled, client: client);
  }

  test('a lite build is offered the lite asset, not the full one', () async {
    final update = await check(
      ['Sonarar-0.3.3-arm64-full.apk', 'Sonarar-0.3.3-arm64-lite.apk'],
      engineBundled: false,
    );

    expect(update?.apkUrl, endsWith('lite.apk'));
  });

  test('a full build is offered the full asset', () async {
    final update = await check(
      ['Sonarar-0.3.3-arm64-full.apk', 'Sonarar-0.3.3-arm64-lite.apk'],
      engineBundled: true,
    );

    expect(update?.apkUrl, endsWith('full.apk'));
  });

  test('an older release with one APK still resolves', () async {
    final update = await check(['Sonarar-0.3.3-arm64.apk'], engineBundled: false);

    expect(update?.apkUrl, endsWith('Sonarar-0.3.3-arm64.apk'),
        reason: 'a matching asset that does not exist must not become no update at all');
  });
}
