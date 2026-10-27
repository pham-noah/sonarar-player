library;

import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlist_loader.dart';
import 'package:sonarar/library/playlists.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.source);
  final String? source;

  @override
  Future<ByteData> load(String key) async => throw FlutterError('not used');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (source == null) throw FlutterError('no bundled seed');
    return source!;
  }
}

String _seed(List<String> ids) =>
    '{"playlists":[{"id":"p3r","name":"P3R","track_ids":'
    '[${ids.map((i) => '"$i"').join(',')}]}]}';

void main() {
  late Directory dir;
  late File file;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('pl');
    file = File('${dir.path}/playlists.json');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PlaylistLoader loader(String? bundled) => PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(bundled),
      );

  group('first run seeds from the bundle', () {
    test('a fresh install gets the bundled playlists', () async {
      final lists = await loader(_seed(['a', 'b']))
          .load(libraryIds: {'a', 'b'});

      expect(lists.length, 1);
      expect(lists.byId('p3r')?.name, 'P3R');
      expect(lists.byId('p3r')?.trackIds, ['a', 'b']);
    });

    test('the seed is WRITTEN OUT, so it becomes an ordinary editable file',
        () async {
      expect(file.existsSync(), isFalse);
      await loader(_seed(['a'])).load(libraryIds: {'a'});
      expect(file.existsSync(), isTrue,
          reason: 'the seed must be copied out, or the next edit has nowhere to go');
    });

    test('a seed whose tracks are all missing leaves no playlist behind', () async {
      final lists = await loader(_seed(['gone'])).load(libraryIds: {});
      expect(lists.length, 0,
          reason: 'the folder would answer to nothing in this library, so it is not '
              'a folder worth showing — it used to stay as an empty shell');
    });
  });

  group('the writable file always wins over the bundle', () {
    test('an existing file is not overwritten by the seed', () async {
      final store = PlaylistStore(file);
      final mine = PlaylistList();
      mine.create('My Mix', id: 'mine', trackIds: ['a']);
      await store.save(mine);

      final lists = await loader(_seed(['a', 'b'])).load(libraryIds: {'a', 'b'});

      expect(lists.byId('mine'), isNotNull, reason: 'his playlist must survive');
      expect(lists.byId('mine')!.trackIds, ['a']);
    });

    test('a seeded playlist he does NOT have DOES arrive', () async {
      final store = PlaylistStore(file);
      final mine = PlaylistList();
      mine.create('My Mix', id: 'mine', trackIds: ['a']);
      await store.save(mine);

      final lists = await loader(_seed(['a', 'b'])).load(libraryIds: {'a', 'b'});

      expect(lists.byId('p3r'), isNotNull,
          reason: 'a playlist added to the seed must reach an existing install');
      expect(lists.byId('p3r')!.trackIds, ['a', 'b']);
    });
  });

  group('pruning', () {
    test('ids that left the library are dropped on load', () async {
      final store = PlaylistStore(file);
      final mine = PlaylistList();
      mine.create('Mix', id: 'm', trackIds: ['keep', 'gone']);
      await store.save(mine);

      final lists = await loader(null).load(libraryIds: {'keep'});

      expect(lists.byId('m')!.trackIds, ['keep'],
          reason: 'a playlist must never show a ghost track');
    });

    test('pruning applies to the seed too', () async {
      final lists =
          await loader(_seed(['keep', 'gone'])).load(libraryIds: {'keep'});
      expect(lists.byId('p3r')!.trackIds, ['keep']);
    });
  });

  group('degenerate cases', () {
    test('no file and no bundle is an empty list, not an error', () async {
      final lists = await loader(null).load(libraryIds: {});
      expect(lists.isEmpty, isTrue);
    });

    test('a malformed bundle does not take the app down', () async {
      final lists = await loader('{not json').load(libraryIds: {});
      expect(lists.isEmpty, isTrue);
    });
  });

  group('playing a playlist', () {
    test('a playlist keeps its OWN order, not the library order', () {
      final lists = PlaylistList();
      lists.create('Mine', id: 'm', trackIds: ['c', 'a', 'b']);
      final ordered = lists.byId('m')!.trackIds;
      expect(ordered, ['c', 'a', 'b']);
    });
  });
}
