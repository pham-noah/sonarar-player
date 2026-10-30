library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/dynamic_mix_resolver.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/rules/context_rules.dart';
import 'package:sonarar/rules/rules_engine.dart' show PlaylistContext;
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: id,
      artist: 'ATLASSoundTeam',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

Playlist _pl(String id, String name, List<String> tracks) =>
    Playlist(id: id, name: name, trackIds: tracks);

PlaylistContext _ctx({
  ContextBand band = ContextBand.morning,
  Sky sky = Sky.unknown,
  String? placeId,
}) =>
    PlaylistContext(
      band: band,
      localHour: 9,
      placeId: placeId,
      sky: sky,
    );

const _resolver = DynamicMixResolver();

MixInputs _inputs({
  PlaylistContext? context,
  List<Playlist> playlists = const [],
  List<Track> library = const [],
  String? bandListName,
  ContextRules? rules,
  bool contextEnabled = true,
  bool honourClock = true,
}) =>
    (
      context: context ?? _ctx(),
      library: library,
      playlists: playlists,
      situationIds: const [],
      bandListName: bandListName,
      rules: rules ?? ContextRules.empty,
      contextEnabled: contextEnabled,
      honourClock: honourClock,
      sleeping: false,
    );

void main() {
  group('the three switches survive a restart', () {
    test('all three default to off — the player is plain until asked', () {
      const fresh = AppPrefs.initial;
      expect(fresh.contextWeather, isFalse);
      expect(fresh.contextClock, isFalse);
      expect(fresh.contextMix, isFalse);
    });

    test('switching them on is what the file says next launch', () {
      final on = AppPrefs.initial.copyWith(
        contextWeather: true,
        contextClock: true,
        contextMix: true,
      );
      final back = AppPrefs.fromJson(on.toJson());
      expect(back.contextWeather, isTrue);
      expect(back.contextClock, isTrue);
      expect(back.contextMix, isTrue);
    });

    test('the six optional layers ship off too', () {
      const fresh = AppPrefs.initial;
      expect(fresh.placesEnabled, isFalse);
      expect(fresh.learnFromSkips, isFalse);
      expect(fresh.weatherVariants, isFalse);
      expect(fresh.autoSkin, isFalse);
      expect(fresh.recordHistory, isTrue,
          reason: 'a history nobody records is a screen that cannot fill');
      expect(fresh.personaLayer, isFalse);
    });

    test('and each one is remembered when switched on', () {
      final on = AppPrefs.initial.copyWith(
        placesEnabled: true,
        learnFromSkips: true,
        weatherVariants: true,
        autoSkin: true,
        recordHistory: true,
        personaLayer: true,
      );
      final back = AppPrefs.fromJson(on.toJson());
      expect(back.placesEnabled, isTrue);
      expect(back.learnFromSkips, isTrue);
      expect(back.weatherVariants, isTrue);
      expect(back.autoSkin, isTrue);
      expect(back.recordHistory, isTrue);
      expect(back.personaLayer, isTrue);
    });

    test('an older settings file without the keys lands on off', () {
      final back = AppPrefs.fromJson(const {'allow_network': true});
      expect(back.contextWeather, isFalse);
      expect(back.contextClock, isFalse);
      expect(back.contextMix, isFalse);
    });
  });

  group('time of day off', () {
    test('the hour no longer chooses the mix', () {
      final lists = [_pl('afternoon', 'Afternoon', ['a', 'b'])];
      final clockOn = _resolver.resolve(_inputs(
        context: _ctx(band: ContextBand.afternoon),
        bandListName: 'afternoon',
        playlists: lists,
        library: [_t('a'), _t('b')],
      ));
      expect(clockOn!.trackIds, ['a', 'b']);

      final clockOff = _resolver.resolve(_inputs(
        context: _ctx(band: ContextBand.afternoon),
        bandListName: 'afternoon',
        playlists: lists,
        library: [_t('a'), _t('b')],
        honourClock: false,
      ));
      expect(clockOff, isNull,
          reason: 'with the clock switched off nothing is left to lead the mix');
    });

    test('a rule written for a time band stops firing', () {
      final rules = ContextRules(const [
        ContextRule(id: 'morning', priority: 10, band: ContextBand.morning),
      ]);
      final ctx = _ctx(band: ContextBand.morning);
      expect(rules.firstMatch(ctx)?.id, 'morning');
      expect(rules.firstMatch(ctx, honourClock: false), isNull);
    });

    test('a rule about the weather still fires with the clock off', () {
      final rules = ContextRules(const [
        ContextRule(id: 'rain', priority: 10, weather: WeatherWant.rain),
      ]);
      final ctx = _ctx(sky: Sky.rain);
      expect(rules.firstMatch(ctx, honourClock: false)?.id, 'rain');
    });
  });

  group('weather off', () {
    test('no reading means no weather rule, whatever the clock says', () {
      final rules = ContextRules(const [
        ContextRule(id: 'rain', priority: 10, weather: WeatherWant.rain),
      ]);
      expect(rules.firstMatch(_ctx(sky: Sky.unknown)), isNull,
          reason: 'the coordinator reports no sky when weather is switched off, '
              'and an unknown sky can never satisfy a rain rule');
    });

    test('no reading means no weather-led list', () {
      final mix = _resolver.resolve(_inputs(
        context: _ctx(sky: Sky.unknown),
        playlists: [_pl('weathering', 'Weathering', ['a'])],
        library: [_t('a')],
      ));
      expect(mix, isNull);
    });
  });

  group('dynamic mix off', () {
    test('the context builds nothing at all', () {
      final mix = _resolver.resolve(_inputs(
        context: _ctx(placeId: 'home'),
        playlists: [_pl('home', 'Home', ['a'])],
        library: [_t('a')],
        contextEnabled: false,
      ));
      expect(mix, isNull);
    });
  });
}
