library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/rules_engine.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, {int minutes = 3}) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: Duration(minutes: minutes),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [
      for (var i = 0; i < n; i++)
        _t('t$i', minutes: [1, 3, 6][i % 3]),
    ];

const _ctx = PlaylistContext(
  band: ContextBand.afternoon,
  sky: Sky.unknown,
  localHour: 14);

const _play = PlayContext(
  band: ContextBand.afternoon,
  sky: Sky.unknown,
  localHour: 14);

void main() {
  group('the engine FILTERS and does not rank', () {
    test('playlist returns the library minus his exclusions, nothing else', () {
      final library = _library(40);
      final engine = RulesEngine();

      final all = engine.playlist(library, _ctx);
      expect(all.length, library.length,
          reason: 'the engine dropped tracks — it is filtering by something other than exclusions');

      final some = engine.playlist(library, _ctx, excluded: {library.first.id});
      expect(some.length, library.length - 1,
          reason: 'an exclusion did not remove exactly the track he excluded');
      expect(some.any((t) => t.id == library.first.id), isFalse);
    });

    test('and it does not change the ORDER it was given', () {
      final library = _library(20);
      final engine = RulesEngine();
      final out = engine.playlist(library, _ctx);
      expect([for (final t in out) t.id], [for (final t in library) t.id],
          reason: 'the engine reordered a list it was given');
    });
  });

  group('the mix is EXACTLY his lists', () {
    AppState wholeLibraryState(int n) {
      final state = AppState();
      state.attachLibrary(_library(n));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t1']),
      ]));
      state.updateContext(_play);
      return state;
    }

    test('a list longer than the cap is capped; a shorter one is not padded', () {
      final state = AppState();
      state.attachLibrary(_library(200));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon',
            trackIds: [for (var i = 0; i < 120; i++) 't$i']),
      ]));
      state.updateContext(_play);
      expect(state.dynamicMix()!.trackIds.length, AppState.kDynamicMixLimit,
          reason: 'a list of 120 was not capped to a session');

      final short = AppState();
      short.attachLibrary(_library(200));
      short.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t5', 't6']),
      ]));
      short.updateContext(_play);
      expect(short.dynamicMix()!.trackIds, ['t5', 't6'],
          reason: 'a short list was padded from the library');
    });

    test('the mix ORDER is the LIST\'s order, not library order', () {
      final state = AppState();
      state.attachLibrary(_library(30));

      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon',
            trackIds: const ['t9', 't2', 't20', 't5']),
      ]));
      state.updateContext(_play);

      final mix = state.dynamicMix()!;
      expect(mix.trackIds, ['t9', 't2', 't20', 't5'],
          reason: 'the mix is not the list he curated, in his order');

      expect(mix.trackIds.length, 4,
          reason: 'the mix contains tracks from outside his lists');
    });

    test('pressing it gives a LIVE queue that is EXACTLY the mix', () {
      final state = wholeLibraryState(30);

      expect(state.playDynamic(), isTrue);
      expect(state.source, QueueSource.live,
          reason: 'Dynamic must be live, or it cannot re-rank while he listens');
      expect(state.queue!.order.length, state.dynamicMix()!.trackIds.length);
      expect(state.queue!.order.first.id, 't1',
          reason: 'the pressed queue is not his list in his order');
    });

    test('it RE-RANKS when the SITUATION changes', () {
      final state = AppState();
      final lib = _library(30);
      state.attachLibrary(lib);

      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t7', 't19']),
        Playlist(id: 'v_evening', name: 'Evening', trackIds: const ['t4', 't16']),
      ]));
      state.updateContext(_play);
      expect(state.playDynamic(), isTrue);
      final before = [for (final t in state.queue!.order) t.id];
      expect(before.take(2).toSet(), {'t7', 't19'},
          reason: 'the afternoon playlist did not lead — the situation is not ranking');

      state.updateContext(const PlayContext(
        band: ContextBand.evening, sky: Sky.unknown, localHour: 20));
      final after = [for (final t in state.queue!.order) t.id];

      expect(after.length, lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'the re-rank is unbounded — it is not the mix');
      expect(after, isNot(before),
          reason: 'the queue did not re-rank when the situation changed');
      expect(after.take(2).toSet(), {'t4', 't16'},
          reason: 'the evening queue does not lead with the EVENING playlist — the situation is not ranking');
    });

    test('the PRESS, the ROW and a CONTEXT CHANGE all agree on the mix', () {
      final state = AppState();
      final lib = _library(100);
      state.attachLibrary(lib);
      expect(lib.length, greaterThan(AppState.kDynamicMixLimit),
          reason: 'the fixture must exceed the cap, or capped and uncapped look identical');

      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon',
            trackIds: [for (var i = 0; i < 100; i++) 't$i']),
        Playlist(id: 'v_evening', name: 'Evening',
            trackIds: [for (var i = 0; i < 100; i++) 't${i + 100}']),
      ]));
      state.updateContext(_play);

      final fromRow = state.dynamicMix()!.trackIds.length;
      expect(fromRow, AppState.kDynamicMixLimit,
          reason: 'the row is not the bounded mix');

      expect(state.playDynamic(), isTrue);
      final fromPress = state.queue!.order.length;
      expect(fromPress, fromRow,
          reason: 'the queue you get by pressing is not the size of the row you pressed');

      state.updateContext(const PlayContext(
        band: ContextBand.evening, sky: Sky.unknown, localHour: 20));
      final afterMove = state.queue!.order.length;
      expect(afterMove, lessThanOrEqualTo(AppState.kDynamicMixLimit),
          reason: 'a context change re-derived from the WHOLE library — the two definitions are back');
      expect(afterMove, lessThan(lib.length),
          reason: 'the re-rank is not a session — it is every track he owns');
    });
  });
}
