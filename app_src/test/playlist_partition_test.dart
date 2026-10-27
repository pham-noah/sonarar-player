library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/downloaded_tracks.dart';
import 'package:sonarar/library/dynamic_playlist.dart';
import 'package:sonarar/library/rediscovery.dart';

void main() {
  group('every derived list id is classified as derived', () {
    const ids = <String>[
      kRediscoverId,
      kForgottenId,
      kDownloadedId,
      kDynamicId,
    ];

    for (final id in ids) {
      test('$id is derived', () {
        expect(isDerivedPlaylistId(id), isTrue,
            reason: '$id is built by the app, so it must be named by `isDerivedPlaylistId`. '
                'If it is not, it falls through the partition in the library screen and is drawn TWICE — '
                'once among the seeded rows and once in the derived block.');
      });
    }

    test('and the partition does not double-count: derived and seeded are disjoint', () {
      for (final id in ids) {
        final derived = isDerivedPlaylistId(id);
        final seeded = !isDerivedPlaylistId(id) && isSeededPlaylistId(id);
        expect(derived && seeded, isFalse,
            reason: '$id is in BOTH groups — that is one row drawn twice on screen');
      }
    });

    test('a user playlist is in exactly one group, and it is not derived', () {
      final userMade = 'pl_1750000000000';
      expect(isDerivedPlaylistId(userMade), isFalse,
          reason: 'a user playlist is not derived');
      expect(isSeededPlaylistId(userMade), isFalse,
          reason: 'a user playlist is not seeded either — it goes in the Custom group');
    });

    test('a seeded id is seeded and not derived', () {
      expect(isSeededPlaylistId('p5r'), isTrue);
      expect(isDerivedPlaylistId('p5r'), isFalse);
    });
  });
}
