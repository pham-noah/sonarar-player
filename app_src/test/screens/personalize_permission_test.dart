import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/storage_permission.dart';
import 'package:sonarar/screens/personalize_screen.dart';

/// ADD PICTURE used to say "no pictures found" when the truth was that the app
/// was not allowed to look. A denial and an empty phone are different problems.
void main() {
  test('a denial is named as a denial', () {
    final message = noPicturesMessage(StorageAccess.denied).toLowerCase();
    expect(message, contains('allow photo access'));
    expect(message, isNot(contains('no pictures found')));
  });

  test('an empty phone still says the folders are empty', () {
    for (final access in [StorageAccess.granted, StorageAccess.unknown]) {
      expect(
        noPicturesMessage(access).toLowerCase(),
        contains('no pictures found'),
        reason: 'access=$access',
      );
    }
  });
}
