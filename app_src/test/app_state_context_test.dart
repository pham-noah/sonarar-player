library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/context/places.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

AppState _state() => AppState()
  ..attachLibrary([for (var i = 0; i < 4; i++) _t('t$i')]);

NamedPlace _place(String id, {String? playlist}) => NamedPlace(
      id: id,
      name: id,
      anchors: const [PlaceAnchor(latitude: 51.5, longitude: -0.12)],
      playlist: playlist,
    );

PlayContext _ctx(ContextBand band, {int hour = 9}) =>
    PlayContext(band: band, localHour: hour);

/// The context cluster: what the app knows about where and when it is, and the
/// rules that follow from it. Extracted so its rules cannot disagree with the
/// places they were derived from — the old failure was editing a place and having
/// yesterday's rules still match.
void main() {
  group('the rules are derived, not maintained', () {
    test('a place with a playlist contributes a rule', () {
      final state = _state();

      state.setPlaces(PlaceBook([_place('home', playlist: 'Rainy Window')]));

      final ids = [for (final r in state.contextRules.rules) r.id];
      expect(ids, contains('place-home'));
      expect(state.contextRules.rules.first.playlist, 'Rainy Window');
    });

    test('a place with no playlist contributes nothing', () {
      final state = _state();

      state.setPlaces(PlaceBook([_place('work')]));

      expect(state.contextRules.rules, isEmpty,
          reason: 'a place is a rule only once it says what to play');
    });

    test('clearing the places takes their rules with them', () {
      final state = _state();
      state.setPlaces(PlaceBook([_place('home', playlist: 'Rainy Window')]));
      expect(state.contextRules.rules, isNotEmpty);

      state.setPlaces(PlaceBook.empty);

      expect(state.contextRules.rules, isEmpty,
          reason: 'a deleted place cannot keep matching');
    });

    test('the written rules survive the places being replaced', () {
      final state = _state();
      state.setContextRules(ContextRules(const [
        ContextRule(id: 'written', priority: 90, playlist: 'Night Drive'),
      ]));

      state.setPlaces(PlaceBook([_place('home', playlist: 'Rainy Window')]));

      final ids = [for (final r in state.contextRules.rules) r.id];
      expect(ids, containsAll(['written', 'place-home']));
      expect(state.writtenRules.rules.map((r) => r.id), ['written'],
          reason: 'what the user wrote is not what the app derived');
    });
  });

  group('a mutation tells the listener', () {
    test('setting the places notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.setPlaces(PlaceBook([_place('home', playlist: 'Rainy Window')]));

      expect(notified, greaterThan(0));
    });

    test('setting the rules notifies', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.setContextRules(ContextRules(const [
        ContextRule(id: 'written', priority: 90, playlist: 'Night Drive'),
      ]));

      expect(notified, greaterThan(0));
    });

    test('entering and leaving a mode notifies', () {
      final state = _state();
      state.updateContext(_ctx(ContextBand.morning));
      var notified = 0;
      state.addListener(() => notified++);

      state.enterMode(ManualMode.darkHour);
      expect(notified, greaterThan(0));
      final afterEnter = notified;

      state.exitMode();
      expect(notified, greaterThan(afterEnter));
    });
  });

  group('the manual mode', () {
    test('wins over the clock while its band is still where it started', () {
      final state = _state();
      state.updateContext(_ctx(ContextBand.morning));

      state.enterMode(ManualMode.darkHour);
      state.updateContext(_ctx(ContextBand.morning, hour: 9));

      expect(state.manualMode, ManualMode.darkHour);
      expect(state.playlistContext!.band, ContextBand.darkHour,
          reason: 'the pinned band is what the playlists are chosen from');
    });

    test('is let go when the clock crosses into another band', () {
      final state = _state();
      state.updateContext(_ctx(ContextBand.morning));
      state.enterMode(ManualMode.battle);

      state.updateContext(_ctx(ContextBand.night, hour: 22));

      expect(state.manualMode, isNull,
          reason: 'a mode pinned in the morning cannot own the night');
      expect(state.playlistContext!.band, ContextBand.night);
    });

    test('cannot be pinned before the app knows what time it is', () {
      final state = _state();
      var notified = 0;
      state.addListener(() => notified++);

      state.enterMode(ManualMode.battle);

      expect(state.manualMode, isNull);
      expect(notified, 0, reason: 'nothing changed, so nothing is redrawn');
    });
  });

  group('the context the app hands out', () {
    test('is the one the cluster read, not a copy taken earlier', () {
      final state = _state();

      state.updateContext(_ctx(ContextBand.evening, hour: 19));

      expect(state.playlistContext, isNotNull);
      expect(state.playlistContext!.band, ContextBand.evening);
      expect(state.playlistContext!.localHour, 19);
    });
  });
}
