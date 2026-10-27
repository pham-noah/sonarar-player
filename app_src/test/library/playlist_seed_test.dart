library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlist_loader.dart';
import 'package:sonarar/library/playlists.dart';

class _FakeBundle extends AssetBundle {
  _FakeBundle(this.source);
  final String source;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(source.codeUnits));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => source;
}

String _seed(List<(String id, String name, List<String> ids)> lists) {
  final b = StringBuffer('{"playlists":[');
  for (var i = 0; i < lists.length; i++) {
    final (id, name, ids) = lists[i];
    if (i > 0) b.write(',');
    b.write('{"id":"$id","name":"$name","track_ids":[');
    b.write(ids.map((x) => '"$x"').join(','));
    b.write(']}');
  }
  b.write(']}');
  return b.toString();
}

void main() {
  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('plseed');
    file = File('${tmp.path}/playlists.json');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  const library = {'t1', 't2', 't3', 't4', 't5'};

  group('a fresh install gets the whole seed', () {
    test('no writable file means the seed is written out whole', () async {
      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([
          ('p3r', 'P3R', ['t1']),
          ('p4r', 'P4R', ['t2']),
        ])),
      );

      final got = await loader.load(libraryIds: library);
      expect(got.all.length, 2);
      expect(file.existsSync(), isTrue, reason: 'the seed becomes the file');
    });
  });

  group('THE BUG: a seed that grows reaches an existing install', () {
    test('a playlist added to the seed ARRIVES on the next launch', () async {
      await PlaylistStore(file).save(
        PlaylistStore.decode(_seed([('p3r', 'P3R', ['t1'])])),
      );

      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([
          ('p3r', 'P3R', ['t1']),
          ('p4r', 'P4R', ['t2']),
          ('p5r', 'P5R', ['t3']),
          ('weathering', 'Weathering With You', ['t4']),
        ])),
      );

      final got = await loader.load(libraryIds: library);
      final ids = got.all.map((p) => p.id).toSet();
      expect(ids, {'p3r', 'p4r', 'p5r', 'weathering'});
    });

    test('the additions are persisted, so the next run is already right', () async {
      await PlaylistStore(file).save(
        PlaylistStore.decode(_seed([('p3r', 'P3R', ['t1'])])),
      );
      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([
          ('p3r', 'P3R', ['t1']),
          ('p4r', 'P4R', ['t2']),
        ])),
      );
      await loader.load(libraryIds: library);

      final onDisk = await PlaylistStore(file).load();
      expect(onDisk.all.map((p) => p.id).toSet(), {'p3r', 'p4r'});
    });
  });

  group('the merge never overwrites what the user did', () {
    test('an EDITED seeded playlist is left completely alone', () async {
      await PlaylistStore(file).save(
        PlaylistStore.decode(_seed([('p3r', 'My P3R', ['t2', 't5'])])),
      );

      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([('p3r', 'P3R', ['t1']), ('p4r', 'P4R', ['t3'])])),
      );

      final got = await loader.load(libraryIds: library);
      final p3r = got.all.firstWhere((p) => p.id == 'p3r');
      expect(p3r.name, 'My P3R', reason: 'the rename must survive');
      expect(p3r.trackIds, ['t2', 't5'], reason: 'the edit must survive');

      expect(got.all.map((p) => p.id), contains('p4r'));
    });

    test('a DELETED seeded playlist STAYS deleted', () async {
      await PlaylistStore(file).save(
        PlaylistStore.decode(_seed([('mine', 'Mine', ['t1'])])),
      );

      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([('p3r', 'P3R', ['t1'])])),
      );

      final got = await loader.load(libraryIds: library);
      expect(got.all.map((p) => p.id).toSet(), {'mine', 'p3r'});
    });

    test('an unchanged seed causes NO write at all', () async {
      await PlaylistStore(file).save(
        PlaylistStore.decode(_seed([('p3r', 'P3R', ['t1'])])),
      );
      final before = file.statSync().modified;

      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([('p3r', 'P3R', ['t1'])])),
      );
      await loader.load(libraryIds: library);

      expect(file.statSync().modified, before,
          reason: 'an identical seed must not touch the file');
    });
  });

  group('the seed obeys the same rules as any user file', () {
    test('ids not in the library are pruned from a seeded playlist', () async {
      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([('p3r', 'P3R', ['t1', 'GONE', 't2'])])),
      );
      final got = await loader.load(libraryIds: library);
      expect(got.all.first.trackIds, ['t1', 't2']);
    });

    test('a missing bundle yields nothing rather than throwing', () async {
      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle('not json at all'),
      );
      final got = await loader.load(libraryIds: library);
      expect(got.all, isEmpty);
    });

    test('duplicate ids inside the seed are dropped, not doubled', () async {
      final loader = PlaylistLoader(
        store: PlaylistStore(file),
        bundle: _FakeBundle(_seed([
          ('p3r', 'P3R', ['t1']),
          ('p3r', 'P3R again', ['t2']),
        ])),
      );
      final got = await loader.load(libraryIds: library);
      expect(got.all.length, 1);
    });
  });
}
