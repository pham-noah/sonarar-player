library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';

Playlist _pl(String id, String name, List<String> tracks) =>
    Playlist(id: id, name: name, trackIds: tracks);

void main() {
  group('the app ships no playlists of its own', () {
    test('the bundled seed is empty', () {
      final seed = File('assets/config/playlists.json');
      expect(seed.existsSync(), isTrue);
      final decoded = jsonDecode(seed.readAsStringSync()) as Map<String, dynamic>;
      final lists = decoded['playlists'] as List;
      expect(lists, isEmpty,
          reason: 'a new install starts with the library it was given and no folders '
              'invented for it — anything here shows up on the first screen and is not his');
    });
  });

  group('leftovers from the old seed are cleaned up', () {
    test('an empty seed list is dropped', () {
      final lists = PlaylistList([
        _pl('p3r', 'P3R', const []),
        _pl('gym', 'Gym', const []),
      ]);
      expect(lists.dropEmptySeeds(), 2);
      expect(lists.all, isEmpty);
    });

    test('a seed list that still holds tracks is kept', () {
      final lists = PlaylistList([
        _pl('p3r', 'P3R', const ['a', 'b']),
        _pl('kpop', 'KPOP', const []),
      ]);
      expect(lists.dropEmptySeeds(), 1);
      expect(lists.all.map((p) => p.id), ['p3r']);
    });

    test('a list he made is never touched, even when empty', () {
      final lists = PlaylistList([
        _pl('pl_1700000000000', 'Sunday morning', const []),
        _pl('home', 'Home', const []),
      ]);
      expect(lists.dropEmptySeeds(), 1);
      expect(lists.all.map((p) => p.id), ['pl_1700000000000'],
          reason: 'an empty list he created is his to fill or delete');
    });

    test('pruning the library first is what makes a seed list empty', () {
      final lists = PlaylistList([
        _pl('p3r', 'P3R', const ['gone-1', 'gone-2']),
        _pl('p4r', 'P4R', const ['kept']),
      ]);
      lists.prune({'kept'});
      expect(lists.dropEmptySeeds(), 1);
      expect(lists.all.map((p) => p.id), ['p4r']);
    });
  });
}
