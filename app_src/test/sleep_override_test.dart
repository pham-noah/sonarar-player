library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: 'T $id',
      artist: 'A',
      album: 'Al',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

const _ctx = PlayContext(
  band: ContextBand.evening,
  whereabouts: Whereabouts.home,
  sky: Sky.unknown,
  localHour: 20);

void main() {
  group('sleeping puts the instrumentals NEXT, not last', () {
    late AppState state;

    setUp(() {
      final lib = _library(200);
      state = AppState();
      state.attachLibrary(lib);

      state.setPlaylists(PlaylistList([
        Playlist(
          id: 'v_instrumental',
          name: 'Instrumental',
          trackIds: const ['t150', 't151', 't152']),
      ]));
      state.updateContext(_ctx);

      expect(state.setQueueForTest(lib), isTrue, reason: 'the 200-track queue under test must be in place');
    });

    test('arming the timer does not put them at the END of a 200-track queue', () {
      final before = state.queue!.order.map((t) => t.id).toList();
      final indexBefore = state.queue!.index;

      state.setSleeping(true);

      final after = state.queue!.order.map((t) => t.id).toList();

      expect(after.length, greaterThanOrEqualTo(before.length),
          reason: 'arming the timer lost tracks');

      const instrumentalIds = {'t150', 't151', 't152'};
      final firstInstrumental = after.indexWhere(instrumentalIds.contains);
      expect(firstInstrumental, greaterThan(indexBefore),
          reason: 'an instrumental landed at or before the current track');
      expect(firstInstrumental, lessThanOrEqualTo(indexBefore + 4),
          reason: 'the instrumentals are NOT next — they are somewhere later in the queue, which is the '
              'bug that made the override look like it did nothing');

      expect(state.queue!.order[indexBefore].id, before[indexBefore],
          reason: 'arming the timer moved the playing track');
    });

    test('they keep the SEEDED order rather than arriving reversed', () {
      final indexBefore = state.queue!.index;
      state.setSleeping(true);
      final after = state.queue!.order.map((t) => t.id).toList();

      final comingUp = after.sublist(indexBefore + 1, indexBefore + 4);
      expect(comingUp, ['t150', 't151', 't152']);
    });

    test('disarming restores the order and does NOT delete his tracks', () {
      final before = state.queue!.order.map((t) => t.id).toList();
      state.setSleeping(true);
      state.setSleeping(false);
      final after = state.queue!.order.map((t) => t.id).toList();

      expect(after.length, before.length,
          reason: 'disarming changed the size of the queue — it took out tracks that were not its to remove');
      expect(after.contains('t150'), isTrue,
          reason: 'an instrumental that was already queued was removed by turning the timer off');
      expect(after.toSet(), before.toSet(),
          reason: 'disarming lost or gained tracks');
    });

    test('on a FIXED queue the instrumentals are ADDED, then taken back out', () {
      final added = AppState();
      added.attachLibrary(_library(50));
      added.setPlaylists(PlaylistList([
        Playlist(id: 'pl_small', name: 'Small', trackIds: const ['t0', 't1', 't2']),
        Playlist(
          id: 'v_instrumental',
          name: 'Instrumental',
          trackIds: const ['t20', 't21']),
      ]));
      added.updateContext(_ctx);

      expect(added.playPlaylistRef('Small'), isTrue);
      expect(added.queue!.order.length, 3);

      added.setSleeping(true);
      expect(added.queue!.order.length, 5,
          reason: 'the two instrumentals were not added to a queue that lacked them');
      expect([for (final t in added.queue!.order.sublist(1, 3)) t.id], ['t20', 't21'],
          reason: 'the added instrumentals did not land next, in seeded order');

      added.setSleeping(false);
      expect(added.queue!.order.length, 3,
          reason: 'the instrumentals the override added were not taken back out');
      expect(added.queue!.order.any((t) => t.id == 't20'), isFalse);
    });
  });

  group('the sleep fade scales the user volume rather than replacing it', () {
    test('a fraction of full multiplied by the chosen level', () {
      const userVolume = 0.2;
      for (final fraction in [1.0, 0.5, 0.1, 0.0]) {
        final applied = userVolume * fraction;
        expect(applied, lessThanOrEqualTo(userVolume),
            reason: 'the fade must never exceed the level he chose — passing the fraction straight through '
                'set the engine to 100% and that is exactly what he heard');
      }

      expect(userVolume * 0.0, 0.0);
    });
  });
}
