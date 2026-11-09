// Hostile-library QA. These tests assert what the app promises a user:
// a bad manifest in the music folder must not take the player down with it.
//
// Every test here describes DESIRED behaviour. A red test is a real defect in
// the shipping code, not a bad expectation — the repro is the test.
@Tags(['adversarial'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/constants.dart';
import 'package:sonarar/library/library_repository.dart';
import 'package:sonarar/library/track.dart';

Map<String, Object?> trackJson({
  String id = 't1',
  Object? duration = 120,
  Object? gain = 0.0,
  Object? romaji,
  Object? variant,
  String file = 'a/b.mp3',
}) =>
    {
      'id': id,
      'title': 'Title',
      'artist': 'Artist',
      'album': 'Album',
      'duration_s': duration,
      'file': file,
      'cover': 'a/b.jpg',
      'gain_db': gain,
      if (romaji != null) 'romaji': romaji,
      if (variant != null) 'variant': variant,
    };

String manifestOf(List<Map<String, Object?>> tracks) =>
    jsonEncode({'tracks': tracks});

void main() {
  group('Track.fromJson tolerates a hand-edited manifest', () {
    test('a numeric gain_db does not throw', () {
      final t = Track.fromJson(trackJson(gain: 3));
      expect(t.gainDb, 3.0);
    });

    test('a textual gain_db is ignored, not fatal', () {
      expect(
        () => Track.fromJson(trackJson(gain: 'loud')),
        returnsNormally,
        reason: 'one bad field must not lose the whole library',
      );
    });

    test('a numeric romaji field is ignored, not fatal', () {
      expect(() => Track.fromJson(trackJson(romaji: 5)), returnsNormally);
    });

    test('a numeric variant field is ignored, not fatal', () {
      expect(() => Track.fromJson(trackJson(variant: 7)), returnsNormally);
    });

    test('an infinite duration is clamped, not thrown', () {
      expect(
        () => Track.fromJson(trackJson(duration: double.infinity)),
        returnsNormally,
      );
    });

    test('a negative duration is not kept as a negative playing time', () {
      final t = Track.fromJson(trackJson(duration: -12));
      expect(t.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('duplicate ids are refused or deduped', () {
      final list = Track.listFromManifest(
        manifestOf([trackJson(id: 'same'), trackJson(id: 'same', file: 'b.mp3')]),
      );
      final ids = list.map((t) => t.id).toSet();
      expect(ids.length, list.length, reason: 'two tracks share an id');
    });

    test('tracks with no file are still dropped', () {
      final list = Track.listFromManifest(manifestOf([
        trackJson(),
        trackJson(id: 't2', file: ''),
      ]));
      expect(list.map((t) => t.id), ['t1']);
    });

    test('a manifest that is not JSON at all throws a typed FormatException', () {
      expect(
        () => Track.listFromManifest('{"tracks": ['),
        throwsA(isA<FormatException>()),
      );
    });

    test('random JSON shapes either parse or fail as FormatException only', () {
      final rng = Random(1234);
      Object? value(int depth) {
        final pick = rng.nextInt(depth > 3 ? 5 : 7);
        return switch (pick) {
          0 => null,
          1 => rng.nextBool(),
          2 => rng.nextInt(1000000) - 500000,
          3 => rng.nextDouble() * 1e6,
          4 => 'text' * rng.nextInt(3),
          5 => [for (var i = 0; i < rng.nextInt(4); i++) value(depth + 1)],
          _ => {
              'id': value(depth + 1),
              'title': value(depth + 1),
              'duration_s': value(depth + 1),
              'file': value(depth + 1),
              'gain_db': value(depth + 1),
            },
        };
      }

      for (var i = 0; i < 500; i++) {
        final doc = jsonEncode({
          'tracks': [for (var j = 0; j < rng.nextInt(4); j++) value(0)],
        });
        try {
          Track.listFromManifest(doc);
        } on FormatException {
          // Only malformed JSON may be reported that way.
        } on TypeError catch (e) {
          fail('a valid JSON document threw $e\n$doc');
        }
      }
    });
  });

  group('LibraryRepository.load survives a broken manifest', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('sonarar-hostile');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    Future<LibraryRepository> loadWith(String manifest) async {
      File('${dir.path}/$kManifestFileName').writeAsStringSync(manifest);
      final repo = LibraryRepository()..root = dir.path;
      await repo.load();
      return repo;
    }

    test('truncated JSON does not escape load()', () async {
      final repo = LibraryRepository()..root = dir.path;
      File('${dir.path}/$kManifestFileName').writeAsStringSync('{"tracks": [');
      await expectLater(
        repo.load(),
        completes,
        reason: 'this throw is unawaited in initState and stalls the boot',
      );
      expect(repo.isEmpty, isTrue);
    });

    test('one wrong-typed field does not escape load()', () async {
      final repo = LibraryRepository()..root = dir.path;
      File('${dir.path}/$kManifestFileName').writeAsStringSync(
        manifestOf([trackJson(gain: 'loud')]),
      );
      await expectLater(repo.load(), completes);
    });

    test('a valid manifest still loads', () async {
      final repo = await loadWith(manifestOf([trackJson(), trackJson(id: 't2')]));
      expect(repo.tracks.length, 2);
    });

    test('a manifest cannot point a track outside the library root', () async {
      final repo =
          await loadWith(manifestOf([trackJson(file: '../outside.mp3')]));
      // Contained means "no path at all", not "a path that happens to start
      // with the root": `root/../outside.mp3` is not inside the root.
      expect(repo.absoluteFor(repo.tracks.single), isNull);
    });

    test('a traversal that dips inside and back out is still refused', () async {
      final repo = await loadWith(
        manifestOf([trackJson(file: 'album/../../outside.mp3')]),
      );
      expect(repo.absoluteFor(repo.tracks.single), isNull);
    });

    test('a normal nested path still resolves', () async {
      final repo = await loadWith(manifestOf([trackJson(file: 'a/b.mp3')]));
      expect(repo.absoluteFor(repo.tracks.single), endsWith('/a/b.mp3'));
    });
  });
}

