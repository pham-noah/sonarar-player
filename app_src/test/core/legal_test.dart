import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/legal.dart';

/// The licence the app is distributed under is the one it must not omit. Both
/// texts ship as assets and are registered by hand, so this checks that the
/// assets are really in the bundle and really reach the licence list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the GPL text and the notice are in the licence registry', () async {
    registerLicenses();

    final entries = <String, String>{};
    await for (final license in LicenseRegistry.licenses) {
      final packages = license.packages.join(', ');
      final text = license.paragraphs.map((p) => p.text).join('\n');
      entries[packages] = text;
    }

    expect(entries.keys, contains('Sonarar'));
    expect(entries['Sonarar'], contains('GNU GENERAL PUBLIC LICENSE'));
    expect(entries.keys, contains('Third-party notices'));
    expect(entries['Third-party notices'], contains('youtubedl-android'));
  });
}
