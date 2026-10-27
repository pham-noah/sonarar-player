library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/rules/context_change.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/rules/rules_engine.dart';

PlaylistContext _ctx({
  ContextBand band = ContextBand.evening,
  bool atHome = true,
  bool raining = false,
  int localHour = 19,
  ManualMode? mode,
  String? placeId = 'home',
  bool snowing = false,
  bool commuting = false,
  Whereabouts? whereabouts,
}) =>
    PlaylistContext(
      band: band,
      sky: snowing ? Sky.snow : (raining ? Sky.rain : Sky.unknown),
      whereabouts: whereabouts ??
          (commuting
              ? Whereabouts.commuting
              : (atHome ? Whereabouts.home : Whereabouts.unknown)),
      localHour: localHour,
      mode: mode,
      placeId: placeId);

void main() {
  test('a first context is always worth deriving', () {
    expect(contextChanged(null, _ctx()), isTrue);
  });

  test('an identical context does NOT re-derive — that is the guard', () {
    expect(contextChanged(_ctx(), _ctx()), isFalse);
  });

  group('EVERY field that can change the answer is noticed', () {
    test('the BAND', () {
      expect(contextChanged(_ctx(), _ctx(band: ContextBand.night)), isTrue);
    });

    test('the PLACE — the one that was ignored', () {
      expect(contextChanged(_ctx(placeId: 'home'), _ctx(placeId: 'uni')), isTrue);
    });

    test('arriving at NO place, having had one', () {
      expect(contextChanged(_ctx(placeId: 'home'), _ctx(placeId: null)), isTrue);
    });

    test('RAIN', () {
      expect(contextChanged(_ctx(), _ctx(raining: true)), isTrue);
    });

    test('SNOW — separate from rain, so a rain rule cannot fire on a snowy day',
        () {
      expect(contextChanged(_ctx(), _ctx(snowing: true)), isTrue);
    });

    test('AT HOME — stepping out of it is noticed', () {
      expect(
        contextChanged(
          _ctx(whereabouts: Whereabouts.home),
          _ctx(whereabouts: Whereabouts.atPlace),
        ),
        isTrue,
      );
    });

    test('the MODE, when he enters one by hand', () {
      expect(contextChanged(_ctx(), _ctx(mode: ManualMode.battle)), isTrue);
    });

    test('whether a reading arrived at all — the travelling case', () {
      expect(
        contextChanged(
          _ctx(placeId: null, whereabouts: Whereabouts.away),
          _ctx(placeId: null, whereabouts: Whereabouts.unknown),
        ),
        isTrue,
        reason: 'leaving a saved place was not noticed, so the queue would not re-derive',
      );
    });
  });

  test('a change in the HOUR alone does not re-derive — nothing reads it', () {
    expect(contextChanged(_ctx(localHour: 19), _ctx(localHour: 20)), isFalse);
  });
}
