@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/context_rules.dart';
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
      for (var i = 0; i < n; i++) _t('t$i', minutes: [1, 3, 6][i % 3]),
    ];

const _afternoon = PlayContext(
  band: ContextBand.afternoon,
  sky: Sky.unknown,
  localHour: 14);

const _rainyAfternoon = PlayContext(
  band: ContextBand.afternoon,
  sky: Sky.rain,
  localHour: 14);

const _darkHour = PlayContext(
  band: ContextBand.darkHour,
  sky: Sky.unknown,
  localHour: 2);

ContextRules _greedyRule() => ContextRules([
      const ContextRule(
        id: 'commuting',
        priority: 66,
        place: PlaceWant.anywhere,
        playlist: 'Commuting'),
    ]);

void main() {
  group('pressing Dynamic', () {
    testWidgets('gives a LIVE queue holding the CONTEXT MIX', (tester) async {
      final state = AppState();
      final lib = _library(30);
      state.attachLibrary(lib);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t1']),
      ]));
      state.updateContext(_afternoon);

      expect(state.playDynamic(), isTrue);
      expect(state.source, QueueSource.live);
      expect(state.queue!.order.length, state.dynamicMix()!.trackIds.length);
      expect(state.queue!.order.first.id, 't1');
    });
  });

  group('a rule must not take a live queue away', () {
    testWidgets('the queue re-ranks and stays full when a matching rule exists',
        (tester) async {
      final state = AppState();
      final lib = _library(30);
      state.attachLibrary(lib);

      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t0']),

        Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t1']),
      ]));
      state.setContextRules(_greedyRule());
      state.updateContext(_afternoon);
      expect(state.playDynamic(), isTrue);
      final before = [for (final t in state.queue!.order) t.id];

      expect(before.length, state.dynamicMix()!.trackIds.length);

      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t0']),
        Playlist(id: 'v_rain', name: 'Rain', trackIds: const ['t9']),
      ]));
      state.updateContext(_rainyAfternoon);

      expect(state.source, QueueSource.live,
          reason: 'the rule took the live queue away — it is no longer dynamic');
      final after = [for (final t in state.queue!.order) t.id];
      expect(after.first, 't9',
          reason: 'the rain list did not lead — the situation is not reaching the queue');
      expect(after, isNot(before),
          reason: 'the queue did not re-rank when the situation changed');
      expect(after.length, lessThanOrEqualTo(AppState.kDynamicMixLimit));
    });

    testWidgets('but a rule STILL takes a FIXED queue', (tester) async {
      final state = AppState();
      final lib = _library(30);
      state.attachLibrary(lib);
      state.setPlaylists(PlaylistList([
        Playlist(id: 'pl_x', name: 'Mine', trackIds: const ['t0', 't1', 't2']),
        Playlist(id: 'pl_commuting', name: 'Commuting', trackIds: const ['t3']),
      ]));
      state.setContextRules(_greedyRule());
      state.updateContext(_afternoon);

      expect(state.playPlaylistRef('Mine'), isTrue);
      expect(state.source, QueueSource.fixed);

      state.updateContext(_darkHour);
      expect(state.source, QueueSource.fixed);

      expect(state.queue!.order.length, greaterThan(3),
          reason: 'the rule stranded the queue on its one-track list again');
    });
  });
}
