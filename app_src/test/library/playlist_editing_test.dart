library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/playlists.dart';

void main() {
  group('adding a track to a playlist', () {
    test('it goes on the end, so the order is the user\'s own', () {
      final p = Playlist(id: 'a', name: 'Mix');
      p.add('t1');
      p.add('t2');
      expect(p.trackIds, ['t1', 't2']);
    });

    test('the same track twice is refused and reported', () {
      final p = Playlist(id: 'a', name: 'Mix', trackIds: ['t1']);
      expect(p.add('t1'), isFalse,
          reason: 'a silent duplicate is indistinguishable from a bug');
      expect(p.length, 1);
    });

    test('a track can be in MORE THAN ONE playlist', () {
      final lists = PlaylistList();
      final a = lists.create('A', id: 'a');
      final b = lists.create('B', id: 'b');
      expect(a.add('t1'), isTrue);
      expect(b.add('t1'), isTrue);
      expect(a.trackIds, ['t1']);
      expect(b.trackIds, ['t1']);
    });
  });

  group('removing a track from a playlist', () {
    test('takes it out of that playlist only', () {
      final lists = PlaylistList();
      final a = lists.create('A', id: 'a', trackIds: ['t1', 't2']);
      final b = lists.create('B', id: 'b', trackIds: ['t1']);

      a.remove('t1');

      expect(a.trackIds, ['t2']);
      expect(b.trackIds, ['t1'], reason: 'the other playlist is untouched');
    });

    test('removing something that is not there reports false', () {
      final p = Playlist(id: 'a', name: 'Mix', trackIds: ['t1']);
      expect(p.remove('nope'), isFalse);
      expect(p.length, 1);
    });

    test('it does not change the order of what remains', () {
      final p = Playlist(id: 'a', name: 'Mix', trackIds: ['a', 'b', 'c', 'd']);
      p.remove('b');
      expect(p.trackIds, ['a', 'c', 'd'],
          reason: 'removing one track must not reshuffle the rest');
    });
  });

  group('a playlist that loses tracks from the library', () {
    test('prunes them and keeps the rest in order', () {
      final p = Playlist(id: 'a', name: 'Mix', trackIds: ['a', 'gone', 'c']);
      expect(p.prune({'a', 'c'}), 1);
      expect(p.trackIds, ['a', 'c']);
    });
  });
}
