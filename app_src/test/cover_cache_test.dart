library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/widgets/panel_bodies.dart';

void main() {
  setUp(clearCoverCache);
  tearDown(clearCoverCache);

  test('a path is stat-ed ONCE, not once per call', () {
    final dir = Directory.systemTemp.createTempSync('personar-cover-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final present = File('${dir.path}/cover.png')..writeAsBytesSync(const [1, 2, 3]);
    final missing = '${dir.path}/nope.png';

    clearCoverCache();
    expect(coverExistsCacheSize, 0, reason: 'a fresh cache must be empty');

    for (var i = 0; i < 625; i++) {
      coverProviderFor(present.path);
      coverProviderFor(missing);
    }
    expect(coverExistsCacheSize, 2,
        reason: 'the cache did not absorb the repeats — this is the lag: 1250 stats instead of 2');
  });

  test('a present cover resolves, a missing one returns null', () {
    final dir = Directory.systemTemp.createTempSync('personar-cover-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final present = File('${dir.path}/cover.png')..writeAsBytesSync(const [1, 2, 3]);

    expect(coverProviderFor(present.path), isNotNull);
    expect(coverProviderFor('${dir.path}/gone.png'), isNull);

    expect(coverProviderFor(''), isNull);
    expect(coverProviderFor(null), isNull);
    expect(coverExistsCacheSize, 2,
        reason: 'the empty and null cases must not reach the filesystem');
  });

  test('the SECOND lookup does not stat again — the same path, cached', () {
    final dir = Directory.systemTemp.createTempSync('personar-cover-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final present = File('${dir.path}/cover.png')..writeAsBytesSync(const [1, 2, 3]);

    clearCoverCache();
    coverProviderFor(present.path);
    final afterFirst = coverExistsCacheSize;

    present.deleteSync();
    expect(coverProviderFor(present.path), isNotNull,
        reason: 'the second lookup hit the filesystem again — the cache is not being read');
    expect(coverExistsCacheSize, afterFirst,
        reason: 'the cache grew on a repeat lookup');
  });
}
