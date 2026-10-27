library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlists.dart';

class _T {
  const _T(this.artist);
  final String artist;
}

void main() {
  group('creating', () {
    test('a new playlist starts empty with the name given', () {
      final lists = PlaylistList();
      final p = lists.create('Chill', id: 'a');
      expect(p.name, 'Chill');
      expect(p.isEmpty, isTrue);
      expect(lists.length, 1);
    });

    test('a blank name is refused', () {
      expect(() => PlaylistList().create('   '), throwsArgumentError);
    });

    test('the name is trimmed', () {
      expect(PlaylistList().create('  Chill  ', id: 'a').name, 'Chill');
    });

    test('ids are unique across playlists', () {
      final lists = PlaylistList();
      lists.create('One');
      lists.create('Two');
      final ids = lists.all.map((p) => p.id).toSet();
      expect(ids.length, 2);
    });
  });

  group('lookup', () {
    test('by id', () {
      final lists = PlaylistList();
      final p = lists.create('Chill', id: 'x');
      expect(lists.byId('x'), same(p));
      expect(lists.byId('nope'), isNull);
    });

    test('by name is case-insensitive', () {
      final lists = PlaylistList();
      lists.create('P3R', id: 'x');
      expect(lists.byName('p3r')?.id, 'x');
      expect(lists.byName('  P3r ')?.id, 'x');
    });
  });

  group('adding and removing tracks', () {
    test('adds to the end, so order is the user\'s own', () {
      final p = Playlist(id: 'a', name: 'x');
      p.add('t1');
      p.add('t2');
      p.add('t3');
      expect(p.trackIds, ['t1', 't2', 't3']);
    });

    test('the same track twice is refused, not duplicated', () {
      final p = Playlist(id: 'a', name: 'x');
      expect(p.add('t1'), isTrue);
      expect(p.add('t1'), isFalse);
      expect(p.length, 1);
    });

    test('remove reports whether it removed anything', () {
      final p = Playlist(id: 'a', name: 'x', trackIds: ['t1']);
      expect(p.remove('t1'), isTrue);
      expect(p.remove('t1'), isFalse);
      expect(p.isEmpty, isTrue);
    });

    test('contains works', () {
      final p = Playlist(id: 'a', name: 'x', trackIds: ['t1']);
      expect(p.contains('t1'), isTrue);
      expect(p.contains('t2'), isFalse);
    });
  });

  group('reordering', () {
    test('moves a track to a new position', () {
      final p = Playlist(id: 'a', name: 'x', trackIds: ['a', 'b', 'c']);
      p.move(0, 2);
      expect(p.trackIds, ['b', 'c', 'a']);
    });

    test('refuses out-of-range moves rather than corrupting the list', () {
      final p = Playlist(id: 'a', name: 'x', trackIds: ['a', 'b']);
      expect(p.move(5, 0), isFalse);
      expect(p.move(0, 9), isFalse);
      expect(p.trackIds, ['a', 'b']);
    });
  });

  group('renaming', () {
    test('renames', () {
      final p = Playlist(id: 'a', name: 'Old');
      p.rename('New');
      expect(p.name, 'New');
    });

    test('a blank rename is ignored, leaving the old name', () {
      final p = Playlist(id: 'a', name: 'Old');
      p.rename('   ');
      expect(p.name, 'Old', reason: 'a blank name must not wipe the playlist');
    });
  });

  group('pruning against the library', () {
    test('drops ids that are no longer in the library', () {
      final p = Playlist(id: 'a', name: 'x', trackIds: ['keep', 'gone']);
      final removed = p.prune({'keep'});
      expect(removed, 1);
      expect(p.trackIds, ['keep']);
    });

    test('prunes across every playlist', () {
      final lists = PlaylistList([
        Playlist(id: 'a', name: 'A', trackIds: ['keep', 'gone']),
        Playlist(id: 'b', name: 'B', trackIds: ['gone', 'gone2']),
      ]);
      expect(lists.prune({'keep'}), 3);
      expect(lists.byId('a')!.trackIds, ['keep']);
      expect(lists.byId('b')!.isEmpty, isTrue);
    });
  });

  group('deleting', () {
    test('deletes by id and reports it', () {
      final lists = PlaylistList();
      lists.create('A', id: 'a');
      lists.create('B', id: 'b');
      expect(lists.delete('a'), isTrue);
      expect(lists.delete('a'), isFalse);
      expect(lists.length, 1);
      expect(lists.byId('b'), isNotNull);
    });
  });

  group('artists are derived, never stored', () {
    test('distinct, alphabetical, case-insensitive', () {
      final artists = PlaylistList.artistsOf(const [
        _T('ATLUS Sound Team'),
        _T('lotus juice'),
        _T('ATLUS Sound Team'),
        _T('Lotus Juice'),
        _T('  '),
      ]);

      expect(artists.length, 2);
      expect(artists.first, 'ATLUS Sound Team');
    });
  });

  group('the file store', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pl'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('round-trips name and ORDER', () async {
      final store = PlaylistStore(File('${dir.path}/playlists.json'));
      final lists = PlaylistList();
      lists.create('P3R', id: 'p3r', trackIds: ['c', 'a', 'b']);
      await store.save(lists);

      final loaded = await store.load();
      expect(loaded.length, 1);

      expect(loaded.byId('p3r')!.trackIds, ['c', 'a', 'b']);
    });

    test('a missing file is an empty list, not an error', () async {
      final loaded =
          await PlaylistStore(File('${dir.path}/nope.json')).load();
      expect(loaded.isEmpty, isTrue);
    });

    test('a corrupt file is an empty list, not a crash', () async {
      final f = File('${dir.path}/playlists.json');
      f.writeAsStringSync('{not json at all');
      expect((await PlaylistStore(f).load()).isEmpty, isTrue,
          reason: 'refusing to launch is worse than losing the playlists');
    });

    test('a nameless playlist in the file is skipped, not loaded', () async {
      final f = File('${dir.path}/playlists.json');
      f.writeAsStringSync(
          '{"playlists":[{"id":"a","name":"","track_ids":["t"]},'
          '{"id":"b","name":"Good","track_ids":["t"]}]}');
      final loaded = await PlaylistStore(f).load();
      expect(loaded.length, 1);
      expect(loaded.byId('b'), isNotNull);
    });

    test('a duplicate track id inside a playlist is de-duplicated on load',
        () async {
      final f = File('${dir.path}/playlists.json');
      f.writeAsStringSync(
          '{"playlists":[{"id":"a","name":"X","track_ids":["t","t","u"]}]}');
      final loaded = await PlaylistStore(f).load();
      expect(loaded.byId('a')!.trackIds, ['t', 'u']);
    });

    test('non-string ids in the file are dropped rather than crashing', () async {
      final f = File('${dir.path}/playlists.json');
      f.writeAsStringSync(
          '{"playlists":[{"id":"a","name":"X","track_ids":["t",7,null,"u"]}]}');
      final loaded = await PlaylistStore(f).load();
      expect(loaded.byId('a')!.trackIds, ['t', 'u']);
    });
  });
}
