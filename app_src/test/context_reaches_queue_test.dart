library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, {int seconds = 180}) => Track(
      id: id,
      title: id,
      artist: 'a',
      album: 'b',
      duration: Duration(seconds: seconds),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

PlayContext _at({
  ContextBand band = ContextBand.afternoon,
  bool raining = false,
  bool snowing = false,
  bool atHome = false,
  bool commuting = false,
  int hour = 12,
  String? placeId,
}) {
  return PlayContext(
    band: band,

    sky: snowing
        ? Sky.snow
        : (raining ? Sky.rain : Sky.unknown),

    whereabouts: commuting
        ? Whereabouts.commuting
        : (atHome ? Whereabouts.home : Whereabouts.unknown),
    localHour: hour,
    placeId: placeId,
  );
}

void main() {
  group('a curated list LEADS the mix', () {
    test('a SLEEP playlist smaller than any threshold still leads', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_instrumental', name: 'Instrumental', trackIds: const ['t30', 't31', 't32']),
      ]));
      state.setSleeping(true);
      state.updateContext(_at());

      final mix = state.dynamicMix();
      expect(mix, isNotNull);
      expect(mix!.trackIds.take(3), ['t30', 't31', 't32'],
          reason: 'the sleep instrumentals did not lead the mix — sleep is not reaching the queue');
    });

    test('a PLACE playlist leads by the place id, with no rule written', () {
      final state = AppState()..attachLibrary(_library(40));

      state.setPlaylists(PlaylistList([
        Playlist(id: 'home', name: 'Home', trackIds: const ['t20', 't21']),
      ]));
      state.updateContext(_at(placeId: 'home', atHome: true));

      final mix = state.dynamicMix();
      expect(mix!.trackIds.take(2), ['t20', 't21'],
          reason: 'being at home did not lead the mix — the place is being read and then dropped');
    });

    test('and the mix is EXACTLY his lists — nothing behind them', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'home', name: 'Home', trackIds: const ['t20', 't21']),
      ]));
      state.updateContext(_at(placeId: 'home', atHome: true));

      final mix = state.dynamicMix()!;
      expect(mix.trackIds, ['t20', 't21'],
          reason: 'the mix contains tracks from outside his lists — that is the suggestion he removed');
      expect(mix.trackIds.length, lessThanOrEqualTo(AppState.kDynamicMixLimit));
    });
  });

  group('ONE LIST PER CONDITION', () {
    test('a WEATHER list leads while it is raining', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_rain', name: 'Rain', trackIds: const ['t10', 't11']),
      ]));
      state.updateContext(_at(raining: true));
      expect(state.dynamicMix()!.trackIds.take(2), ['t10', 't11'],
          reason: 'the Rain list did not lead while it was raining');
    });

    test('SNOW IS ITS OWN CONDITION — it must not play the rain list', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_rain', name: 'Rain', trackIds: const ['t10']),
        Playlist(id: 'v_snow', name: 'Snow', trackIds: const ['t30', 't31']),
      ]));
      state.updateContext(_at(snowing: true));
      expect(state.dynamicMix()!.trackIds.take(2), ['t30', 't31'],
          reason: 'a snowy moment played the RAIN list — the snow condition is being lost');
    });

    test('a TIME list leads for its own band', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t5', 't6']),
      ]));
      state.updateContext(_at(band: ContextBand.morning, hour: 8));
      expect(state.dynamicMix()!.trackIds.take(2), ['t5', 't6'],
          reason: 'the Morning list did not lead in the morning');
    });

    test('and a DIFFERENT band uses ITS list, not the morning one', () {
      final state = AppState()..attachLibrary(_library(40));
      state.setPlaylists(PlaylistList([
        Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['t5', 't6']),
        Playlist(id: 'v_evening', name: 'Evening', trackIds: const ['t25', 't26']),
      ]));
      state.updateContext(_at(band: ContextBand.evening, hour: 20));
      expect(state.dynamicMix()!.trackIds.take(2), ['t25', 't26'],
          reason: 'the evening used the morning list — the band is not selecting the list');
    });
  });

  group('the hour does NOT filter — the list decides', () {
    test('a long track HE put in the morning list still plays in the morning', () {
      final state = AppState()
        ..attachLibrary([
          ..._library(20),
          _t('long', seconds: 720),
        ])
        ..setPlaylists(PlaylistList([
          Playlist(id: 'v_morning', name: 'Morning', trackIds: const ['long']),
        ]));
      state.updateContext(_at(band: ContextBand.morning, hour: 8));
      final mix = state.dynamicMix()!;
      expect(mix.trackIds, contains('long'),
          reason: 'the hour filtered out a track he deliberately put in the morning list');
      expect(mix.trackIds, ['long'],
          reason: 'the mix contains something outside his list');
    });

    test('a short track HE put in a night list still plays — length is not a mood', () {
      final state = AppState()
        ..attachLibrary([
          ..._library(20),
          _t('sting', seconds: 25),
          _t('short', seconds: 70),
        ])

        ..setPlaylists(PlaylistList([
          Playlist(id: 'v_instrumental', name: 'Instrumental', trackIds: const ['sting', 'short']),
        ]));
      state.setSleeping(true);
      state.updateContext(_at(band: ContextBand.night, hour: 23));
      expect(state.dynamicMix()!.trackIds, ['sting', 'short'],
          reason: 'the night filter dropped short tracks he had chosen');
    });
  });

  group('no fit is a real answer', () {
    test('nothing in his lists means NO music, not a library fallback', () {
      final state = AppState()
        ..attachLibrary([_t('a', seconds: 180), _t('b', seconds: 180)]);
      state.updateContext(_at(band: ContextBand.night, hour: 23));
      expect(state.dynamicMix(), isNull,
          reason: 'no list fits this moment, so the mix must be EMPTY rather than the library');
    });

    test('the mix never contains a track from outside his lists', () {
      final state = AppState()
        ..attachLibrary([_t('wanted', seconds: 180), _t('stray', seconds: 180)])
        ..setPlaylists(PlaylistList([
          Playlist(id: 'v_instrumental', name: 'Instrumental', trackIds: const ['wanted']),
        ]));
      state.setSleeping(true);
      state.updateContext(_at(band: ContextBand.night, hour: 23));
      final mix = state.dynamicMix()!;
      expect(mix.trackIds, ['wanted']);
      expect(mix.trackIds, isNot(contains('stray')),
          reason: 'a track outside his lists appeared in the mix — that is the suggestion he removed');
    });
  });
}
