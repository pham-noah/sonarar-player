import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/exclusions.dart';

void main() {
  group('exclusions', () {
    test('exclude / include / toggle behave as one set', () {
      final e = ExclusionList();
      expect(e.exclude('a'), isTrue);
      expect(e.contains('a'), isTrue);

      expect(e.exclude('a'), isFalse);
      expect(e.include('a'), isTrue);
      expect(e.include('a'), isFalse);
      expect(e.contains('a'), isFalse);

      e.toggle('b');
      expect(e.contains('b'), isTrue);
      e.toggle('b');
      expect(e.contains('b'), isFalse);
    });

    test('excluded ids are exposed but not mutable from outside', () {
      final e = ExclusionList({'a'});
      final snapshot = e.ids;

      expect(() => snapshot.add('b'), throwsUnsupportedError);
      expect(e.length, 1);
    });

    test('prune drops entries for tracks no longer in the library', () {
      final e = ExclusionList({'here', 'gone'});
      final dropped = e.prune({'here', 'other'});
      expect(dropped, 1);
      expect(e.contains('gone'), isFalse);
      expect(e.contains('here'), isTrue);
    });
  });

  group('bookmarks', () {
    test('set, read, remove', () {
      final b = BookmarkList();
      expect(b.at('t'), isNull);
      b.set('t', const Duration(seconds: 90));
      expect(b.at('t'), const Duration(seconds: 90));
      expect(b.has('t'), isTrue);
      b.remove('t');
      expect(b.has('t'), isFalse);
    });

    test('prune drops a bookmark at the start — that is not a bookmark', () {
      final b = BookmarkList({
        'zero': Duration.zero,
        'real': const Duration(minutes: 2),
      });
      final dropped = b.prune({'zero', 'real'});
      expect(dropped, 1);
      expect(b.has('zero'), isFalse);
      expect(b.has('real'), isTrue);
    });

    test('prune drops bookmarks for tracks no longer in the library', () {
      final b = BookmarkList({'gone': const Duration(minutes: 1)});
      expect(b.prune({'other'}), 1);
      expect(b.isEmpty, isTrue);
    });
  });

  group('both survive a round trip through one JSON file', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('personar-lists'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('an exclusion list comes back as it was', () async {
      final store = JsonMapStore<bool>(
        File('${dir.path}/excluded.json'),
        encode: (v) => v,
        decode: (v) => v is bool ? v : null,
      );
      await store.save({'a': true, 'b': true});
      final back = await store.load();
      expect(back.keys.toSet(), {'a', 'b'});
    });

    test('bookmarks come back in milliseconds', () async {
      final store = JsonMapStore<Duration>(
        File('${dir.path}/bookmarks.json'),
        encode: (v) => v.inMilliseconds,
        decode: (v) => v is num ? Duration(milliseconds: v.toInt()) : null,
      );
      await store.save({'t': const Duration(minutes: 3, seconds: 7)});
      final back = await store.load();
      expect(back['t'], const Duration(minutes: 3, seconds: 7));
    });

    test('a truncated file reads as empty rather than crashing launch', () async {
      final f = File('${dir.path}/excluded.json');
      f.writeAsStringSync('{"a": tr');
      final store = JsonMapStore<bool>(f, encode: (v) => v, decode: (v) => v is bool ? v : null);
      expect(await store.load(), isEmpty);
    });

    test('a missing file reads as empty', () async {
      final store = JsonMapStore<bool>(
        File('${dir.path}/nope.json'),
        encode: (v) => v,
        decode: (v) => v is bool ? v : null,
      );
      expect(await store.load(), isEmpty);
    });

    test('an entry with an unusable value is skipped, not fatal', () async {
      final f = File('${dir.path}/bookmarks.json');
      f.writeAsStringSync('{"good": 5000, "bad": "not a number"}');
      final store = JsonMapStore<Duration>(
        f,
        encode: (v) => v.inMilliseconds,
        decode: (v) => v is num ? Duration(milliseconds: v.toInt()) : null,
      );
      final back = await store.load();
      expect(back.keys, ['good']);
      expect(back['good'], const Duration(seconds: 5));
    });
  });
}
