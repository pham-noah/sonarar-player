library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

AppState _state([int n = 4]) => AppState()
  ..attachLibrary([for (var i = 0; i < n; i++) _t('t$i')]);

void main() {
  group('the DATA stays correct however it is reached', () {
    test('a favourite is in the set, and the order is the order it was liked', () {
      final state = _state();
      state.addFavorite('t0');
      state.addFavorite('t2');
      expect(state.favorites.ids, {'t0', 't2'});
      expect(state.favorites.orderedIds, ['t0', 't2'],
          reason: 'the order is what the Liked Songs view shows');
    });

    test('an exclusion sticks, and toggling reverses it', () {
      final state = _state();
      state.toggleExclusion('t1');
      expect(state.exclusions.contains('t1'), isTrue);
      state.toggleExclusion('t1');
      expect(state.exclusions.contains('t1'), isFalse);
    });

    test('a bookmark is stored against its track', () {
      final state = _state();
      state.setBookmark('t3', const Duration(minutes: 1, seconds: 30));
      expect(state.bookmarks.has('t3'), isTrue);
      expect(state.bookmarks.at('t3'), const Duration(minutes: 1, seconds: 30));
    });

    test('pruning drops what the library no longer has', () {
      final state = _state();
      state.addFavorite('t0');
      state.addFavorite('ghost');
      state.toggleExclusion('ghost');
      state.setBookmark('ghost', const Duration(seconds: 5));

      final gone = state.pruneToLibrary({'t0'}.toSet()..addAll({}));

      expect(state.favorites.contains('ghost'), isFalse);
      expect(state.exclusions.contains('ghost'), isFalse);
      expect(state.bookmarks.has('ghost'), isFalse);
      expect(gone, greaterThan(0), reason: 'the ghosts were pruned');
      expect(state.favorites.contains('t0'), isTrue,
          reason: 'a live track must survive pruning');
    });

    test('a playlist created, added to and deleted lands in the right place', () {
      final state = _state();
      final p = state.createPlaylist('Late Night');
      expect(state.playlists.byId(p.id), isNotNull);

      state.addTrackToPlaylist(p, 't1');
      expect(state.playlists.byId(p.id)!.trackIds, ['t1']);

      state.deletePlaylist(p.id);
      expect(state.playlists.byId(p.id), isNull,
          reason: 'a deleted playlist is gone, not hidden');
    });

    test('ensure returns the same list twice rather than making a twin', () {
      final state = _state();
      expect(state.ensurePlaylist('Rain').id, state.ensurePlaylist('Rain').id);
    });

    test('removing a track from a playlist leaves the library alone', () {
      final state = _state();
      final p = state.createPlaylist('Short');
      state.addTrackToPlaylist(p, 't0');
      state.addTrackToPlaylist(p, 't1');

      state.removeTrackFromPlaylist(p, 't0');

      expect(state.playlists.byId(p.id)!.trackIds, ['t1']);
      expect(state.library.map((t) => t.id).contains('t0'), isTrue,
          reason: 'a playlist is ids, not tracks — the library must be untouched');
    });
  });

  group('THE CONTRACT: every mutation tells the listener', () {
    test('toggling a favourite notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.toggleFavorite('t0');

      expect(notified, greaterThan(0),
          reason: 'a favourite was toggled with no notification — anything '
              'watching the state is now showing the wrong thing');
    });

    test('excluding a track notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.toggleExclusion('t1');

      expect(notified, greaterThan(0));
    });

    test('setting a bookmark notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.setBookmark('t0', const Duration(seconds: 30));

      expect(notified, greaterThan(0));
    });

    test('creating, editing and deleting a playlist notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      final p = state.createPlaylist('Night');
      state.addTrackToPlaylist(p, 't0');
      state.removeTrackFromPlaylist(p, 't0');
      state.deletePlaylist(p.id);

      expect(notified, greaterThan(0));
    });

    test('restoring the saved lists notifies once, not once per line', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.restoreTrackSets(
        excludedIds: const ['t1'],
        bookmarks: const {'t2': Duration(seconds: 40)},
        favoriteIds: const ['t0'],
      );

      state.pruneToLibrary({'t0', 't1', 't2'});

      expect(notified, 1,
          reason: 'a boot restore is ONE change to the state, and a burst of '
              'notifications during boot is a rebuild storm for nothing');
    });
  });

  group('the collections are handed out read-only', () {
    test('favorites exposes its reads', () {
      final state = _state();
      state.addFavorite('t0');
      expect(state.favorites.ids, {'t0'});
      expect(state.favorites.orderedIds, ['t0']);
    });

    test('exclusions exposes its reads', () {
      final state = _state();
      state.toggleExclusion('t0');
      expect(state.exclusions.ids, {'t0'});
      expect(state.exclusions.contains('t0'), isTrue);
    });

    test('bookmarks exposes its reads', () {
      final state = _state();
      state.setBookmark('t0', const Duration(seconds: 10));
      expect(state.bookmarks.all, {'t0': const Duration(seconds: 10)});
      expect(state.bookmarks.has('t0'), isTrue);
      expect(state.bookmarks.at('t0'), const Duration(seconds: 10));
    });

    test('playlists exposes its reads', () {
      final state = _state();
      state.createPlaylist('Night', id: 'pl_night');
      expect(state.playlists.byId('pl_night'), isNotNull);
      expect(state.playlists.all, hasLength(1));
      expect(state.playlists.length, 1);
    });

    test('the read views are unmodifiable', () {
      final state = _state();

      expect(() => state.exclusions.ids.add('t0'), throwsUnsupportedError);
      expect(() => state.favorites.ids.add('t0'), throwsUnsupportedError);
      expect(() => state.bookmarks.all['t0'] = Duration.zero,
          throwsUnsupportedError);
    });
  });
}
