import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/library/storage_permission.dart';
import 'package:sonarar/screens/personalize_screen.dart';

/// The English strings, because this test is about which message is chosen, not
/// about how it reads in Finnish.
final l10n = lookupAppLocalizations(const Locale('en'));

/// ADD PICTURE used to say "no pictures found" when the truth was that the app
/// was not allowed to look. A denial and an empty phone are different problems.
void main() {
  test('a denial is named as a denial', () {
    final message = noPicturesMessage(StorageAccess.denied, l10n).toLowerCase();
    expect(message, contains('allow photo access'));
    expect(message, isNot(contains('no pictures found')));
  });

  test('an empty phone still says the folders are empty', () {
    for (final access in [StorageAccess.granted, StorageAccess.unknown]) {
      expect(
        noPicturesMessage(access, l10n).toLowerCase(),
        contains('no pictures found'),
        reason: 'access=$access',
      );
    }
  });
}
