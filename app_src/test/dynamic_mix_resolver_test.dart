library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/dynamic_mix_resolver.dart';
import 'package:sonarar/library/dynamic_playlist.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/rules_engine.dart' show PlaylistContext;
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

Playlist _pl(String id, String name, List<String> tracks) =>
    Playlist(id: id, name: name, trackIds: tracks);

PlaylistContext _ctx({
  ContextBand band = ContextBand.afternoon,
  String? placeId,
  Sky sky = Sky.unknown,
  Whereabouts whereabouts = Whereabouts.unknown,
}) =>
    PlaylistContext(
      band: band,
      localHour: 15,
      placeId: placeId,
      sky: sky,
      whereabouts: whereabouts,
    );

const _resolver = DynamicMixResolver();

MixInputs inputs({
  PlaylistContext? context,
  List<Playlist> playlists = const [],
  List<Track> library = const [],
  List<String> situationIds = const [],
  String? bandListName,
  ContextRules? rules,
  bool contextEnabled = true,
  bool honourClock = true,
  bool sleeping = false,
}) =>
    (
      context: context ?? _ctx(),
      library: library,
      playlists: playlists,
      situationIds: situationIds,
      bandListName: bandListName,
      rules: rules ?? ContextRules(const []),
      contextEnabled: contextEnabled,
      honourClock: honourClock,
      sleeping: sleeping,
    );

void main() {
  group('no fit, no music', () {
    test('nothing answering for this moment returns null, not arbitrary tracks', () {
      final mix = _resolver.resolve(inputs(
        library: [_t('a'), _t('b'), _t('c')],
      ));
      expect(mix, isNull,
          reason: 'the context had no opinion, so it must not hand back 60 arbitrary '
              'tracks — that is the context failing to choose, with a fallback '
              'covering for it');
    });

    test('a library with no playlist named for a live condition yields nothing', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [_t('a')],
        playlists: [_pl('other', 'Other', ['a'])],
      ));
      expect(mix, isNull,
          reason: 'a place he is standing in has no list, so nothing should play');
    });

    test('an empty library yields null rather than a list of ghosts', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        playlists: [_pl('home', 'Home', ['a'])],
      ));
      expect(mix, isNull);
    });
  });

  group('the mix is his lists, in his order', () {
    test('a place playlist leads by its own id, with no rule written', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'gym'),
        library: [_t('t0'), _t('t1'), _t('t2')],
        playlists: [_pl('gym', 'Gym', ['t1', 't0'])],
      ));
      expect(mix!.trackIds, ['t1', 't0'],
          reason: 'the list\'s own order IS the decision — sorting it is a second opinion');
    });

    test('a playlist is found by its NAME as well as its id', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'uni'),
        library: [_t('t0'), _t('t1')],
        playlists: [_pl('pl_x', 'Uni', ['t0', 't1'])],
      ));
      expect(mix!.trackIds, ['t0', 't1']);
    });

    test('there is no library tail and no ranking', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [_t('t0'), _t('t1'), _t('t2'), _t('t3')],
        playlists: [_pl('home', 'Home', ['t3', 't1'])],
      ));
      expect(mix!.trackIds, ['t3', 't1'],
          reason: 't0 and t2 are in no list, so they must not appear — a mix with a '
              'library tail is the "suggestion from outside" he removed');
    });

    test('a music list that fits is not trimmed', () {
      final ids = [for (var i = 0; i < 12; i++) 't$i'];
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [for (var i = 0; i < 12; i++) _t('t$i')],
        playlists: [_pl('home', 'Home', ids)],
      ));
      expect(mix!.trackIds, ids, reason: 'the cap must not bite below it');
    });
  });

  group('the cap', () {
    test('a list longer than a session is capped, nothing added below it', () {
      final ids = [for (var i = 0; i < kDynamicMixLimit + 25; i++) 't$i'];
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [for (var i = 0; i < ids.length; i++) _t('t$i')],
        playlists: [_pl('home', 'Home', ids)],
      ));
      expect(mix!.trackIds, hasLength(kDynamicMixLimit));
      expect(mix.trackIds.first, 't0');
    });
  });

  group('the conditions, and each one being off', () {
    test('rain takes the weather fallback list, because the sky\'s own are nearly empty', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(sky: Sky.rain),
        library: [_t('t0'), _t('t1')],
        playlists: [_pl('weathering', 'Weathering With You', ['t1'])],
      ));
      expect(mix!.trackIds, ['t1']);
    });

    test('the sky\'s own lists are resolved through the situation', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(sky: Sky.rain),
        library: [_t('t0'), _t('t1')],
        situationIds: ['t0'],
        playlists: [_pl('weathering', 'Weathering With You', ['t1'])],
      ));
      expect(mix!.trackIds, ['t0', 't1'],
          reason: 'the situation leads, so its order survives');
    });

    test('a WET sky that is gated off contributes nothing', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(sky: Sky.rain),
        library: [_t('t0'), _t('t1')],
        situationIds: ['t0'],
        playlists: [_pl('weathering', 'Weathering With You', ['t1'])],
        contextEnabled: false,
      ));
      expect(mix, isNull,
          reason: 'gating only the fallback would leave rain still choosing music — '
              'the sky\'s own lists are the same condition');
    });

    test('the clock leads only for the three bands that have a list', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(band: ContextBand.evening),
        library: [_t('t0'), _t('t1')],
        bandListName: 'v_evening',
        playlists: [_pl('v_evening', 'Evening', ['t0'])],
      ));
      expect(mix!.trackIds, ['t0']);

      final night = _resolver.resolve(inputs(
        context: _ctx(band: ContextBand.night),
        library: [_t('t0')],
        bandListName: 'v_night',
        playlists: [_pl('v_night', 'Night', ['t0'])],
      ));
      expect(night, isNull, reason: 'night has no list, on purpose');
    });

    test('a place he is standing in leads, and the sky leads before it', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(
          placeId: 'home',
          whereabouts: Whereabouts.home,
          sky: Sky.rain,
        ),
        library: [_t('t0'), _t('t1')],
        playlists: [
          _pl('home', 'Home', ['t0']),
          _pl('weathering', 'Weathering With You', ['t1']),
        ],
      ));
      expect(mix!.trackIds, ['t1', 't0'],
          reason: 'every live condition contributes, in the order a moment is felt');
    });
  });

  group('sleep is gated with the other three', () {
    test('an armed timer leads with the instrumentals', () {
      final mix = _resolver.resolve(inputs(
        library: [_t('t0'), _t('t1')],
        playlists: [_pl('v_instrumental', 'Instrumental', ['t1'])],
        sleeping: true,
      ));
      expect(mix!.trackIds, ['t1']);
    });

    test('an armed timer contributes nothing with the switch off', () {
      final mix = _resolver.resolve(inputs(
        library: [_t('t0'), _t('t1')],
        playlists: [_pl('v_instrumental', 'Instrumental', ['t1'])],
        contextEnabled: false,
        sleeping: true,
      ));
      expect(mix, isNull,
          reason: 'the instrumental list is one of the fourteen the switch stops — '
              'this is the behaviour, whatever the old comment claimed');
    });
  });

  group('a rule he wrote', () {
    test('a matching rule leads with its own list', () {
      final rules = ContextRules([        ContextRule(id: 'r1', priority: 1, band: ContextBand.evening, playlist: 'LateNight'),
      ]);
      final mix = _resolver.resolve(inputs(
        context: _ctx(band: ContextBand.evening),
        library: [_t('t0'), _t('t1')],
        rules: rules,
        playlists: [_pl('ln', 'LateNight', ['t0', 't1'])],
      ));
      expect(mix!.trackIds, ['t0', 't1']);
    });

    test('a rule that does not match contributes nothing', () {
      final rules = ContextRules([        ContextRule(id: 'r1', priority: 1, band: ContextBand.evening, playlist: 'LateNight'),
      ]);
      final mix = _resolver.resolve(inputs(
        context: _ctx(band: ContextBand.morning),
        library: [_t('t0')],
        rules: rules,
        playlists: [_pl('ln', 'LateNight', ['t0'])],
      ));
      expect(mix, isNull);
    });
  });

  group('the mix is a real playlist you can press', () {
    test('the answer has the reserved Dynamic id', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [_t('t0')],
        playlists: [_pl('home', 'Home', ['t0'])],
      ));
      expect(mix, isNotNull);
      expect(mix!.id, kDynamicId, reason: 'the row and the press must be the same playlist');
      expect(mix.name, kDynamicName);
    });

    test('the answer holds IDS, not tracks', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [_t('t0'), _t('t1')],
        playlists: [_pl('home', 'Home', ['t1'])],
      ));
      expect(mix!.trackIds, ['t1']);
      expect(mix.trackIds, everyElement(isA<String>()));
    });

    test('an id the library no longer has is dropped rather than left a hole', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home'),
        library: [_t('t0')],
        playlists: [_pl('home', 'Home', ['t0', 'ghost'])],
      ));
      expect(mix!.trackIds, ['t0'],
          reason: 'a ghost id must not reach the queue');
    });
  });

  group('the same inputs give the same answer', () {
    test('resolving twice is identical', () {
      final args = inputs(
        context: _ctx(placeId: 'home', sky: Sky.rain),
        library: [for (var i = 0; i < 8; i++) _t('t$i')],
        playlists: [
          _pl('home', 'Home', ['t0', 't1', 't2']),
          _pl('weathering', 'Weathering With You', ['t3', 't4']),
        ],
      );
      final first = _resolver.resolve(args);
      final second = _resolver.resolve(args);
      expect(second!.trackIds, first!.trackIds);
    });
  });

  group('order across conditions', () {
    test('sky, then place, then hour, then a rule — first occurrence wins', () {
      final rules = ContextRules([        ContextRule(id: 'r1', priority: 1, band: ContextBand.evening, playlist: 'Rule'),
      ]);
      final mix = _resolver.resolve(inputs(
        context: _ctx(band: ContextBand.evening, placeId: 'home', sky: Sky.rain),
        library: [for (var i = 0; i < 10; i++) _t('t$i')],
        situationIds: ['t0'],
        bandListName: 'v_evening',
        rules: rules,
        playlists: [
          _pl('home', 'Home', ['t2', 't3']),
          _pl('v_evening', 'Evening', ['t4']),
          _pl('weathering', 'Weathering With You', ['t5']),
          _pl('rule', 'Rule', ['t6']),
        ],
      ));
      expect(mix!.trackIds, ['t0', 't5', 't2', 't3', 't4', 't6']);
    });

    test('a track two conditions both want appears once, at its first occurrence', () {
      final mix = _resolver.resolve(inputs(
        context: _ctx(placeId: 'home', sky: Sky.rain),
        library: [_t('t0'), _t('t1')],
        playlists: [
          _pl('weathering', 'Weathering With You', ['t0', 't1']),
          _pl('home', 'Home', ['t0']),
        ],
      ));
      expect(mix!.trackIds, ['t0', 't1'],
          reason: 'the same track twice in one queue is impossible to tell apart');
    });
  });
}
