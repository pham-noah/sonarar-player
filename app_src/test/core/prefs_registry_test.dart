library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs.dart';

/// Everything the registry has to keep true, written before the registry existed.
///
/// The point of the table is a single answer to three questions a key used to answer
/// three times — what it reads as when the file says nothing, what a junk value
/// means, and what the range is. These tests ask each of those once per shape of key,
/// so the table is judged by them rather than the other way round.
void main() {
  group('a key the file does not mention', () {
    test('reads as its default, not as null and not as a crash', () {
      final p = AppPrefs.fromJson(const <String, Object?>{});

      expect(p.resumeOnLaunch, isFalse);
      expect(p.tabAnimation, isTrue, reason: 'a default-true switch stays on');
      expect(p.crossfadeSeconds, 0);
      expect(p.sleepTimerMinutes, 30);
      expect(p.layoutId, 'persona');
      expect(p.paletteIndex, 0);
      expect(p.locale, isNull, reason: 'null is a value here: follow the phone');
      expect(p.libraryIsGrid, isNull, reason: 'three states: grid, list, unset');
    });

    test('an older file that predates versioning keeps the newer defaults', () {
      // Nothing in the file says when it was written, so the safe reading of a
      // missing switch is the default of the build reading it.
      final p = AppPrefs.fromJson(const {'crossfade_seconds': 4});

      expect(p.crossfadeSeconds, 4);
      expect(p.recordHistory, isTrue);
      expect(p.checkForUpdates, isTrue);
      expect(p.refillWhenQueueEnds, isFalse);
    });
  });

  group('a junk value', () {
    test('never breaks a launch, whatever the key', () {
      final junk = <String, Object?>{
        'resume_on_launch': 'yes',
        'crossfade_seconds': 'loud',
        'sleep_timer_minutes': <String>[],
        'skip_threshold_seconds': double.nan,
        'official_only': 1,
        'tab_animation': 'off',
        'show_fps': 3,
        'locale': 42,
        'check_for_updates': const <String>[],
        'weather_refresh_minutes': 'often',
        'allow_network': 'no',
        'context_weather': 1.5,
        'context_clock': 'yes',
        'context_mix': 'yes',
        'places_enabled': 'yes',
        'learn_from_skips': 'yes',
        'weather_variants': 'yes',
        'auto_skin': 'yes',
        'record_history': 'yes',
        'bonds_layer': 'yes',
        'cycle_character_art': 'yes',
        'show_visualiser': 'yes',
        'show_romaji': 'yes',
        'dynamic_by_default': 'yes',
        'refill_when_queue_ends': 'yes',
        'library_is_grid': 'grid',
        'layout_id': 7,
        'palette': 'purple',
        'active_preset': 3,
        'language_skin': false,
        'skin_id': 9,
        'spectrum_smoothness': 'smooth',
        'spectrum_scale': 'big',
        'spectrum_shape': 12,
        'search_online': 'yes',
        'playlist_sort': 1,
        'pinned_playlists': 'none',
        'recent_playlists': {'not': 'a list'},
      };

      final p = AppPrefs.fromJson(junk);

      expect(p.resumeOnLaunch, isFalse);
      expect(p.crossfadeSeconds, 0);
      expect(p.tabAnimation, isTrue);
      expect(p.locale, isNull);
      expect(p.layoutId, 'persona');
      expect(p.paletteIndex, 0);
      expect(p.spectrumSmoothness, isNull);
      expect(p.pinnedPlaylistIds, isNull);
    });
  });

  group('the range is enforced where the value is read', () {
    test('a file with an impossible crossfade is clamped, not obeyed', () {
      expect(AppPrefs.fromJson(const {'crossfade_seconds': 900}).crossfadeSeconds, 12);
      expect(AppPrefs.fromJson(const {'crossfade_seconds': -5}).crossfadeSeconds, 0);
    });

    test('a file with an impossible sleep timer is clamped', () {
      expect(AppPrefs.fromJson(const {'sleep_timer_minutes': 0}).sleepTimerMinutes, 5);
      expect(
        AppPrefs.fromJson(const {'sleep_timer_minutes': 9999}).sleepTimerMinutes,
        180,
      );
    });

    test('a nullable number is clamped when it IS there and stays null when not',
        () {
      expect(AppPrefs.fromJson(const {'spectrum_scale': 999}).spectrumScale, 220);
      expect(AppPrefs.fromJson(const {'spectrum_scale': 5}).spectrumScale, 40);
      expect(AppPrefs.fromJson(const {'spectrum_smoothness': 400}).spectrumSmoothness,
          100);
      expect(AppPrefs.fromJson(const {'spectrum_scale': null}).spectrumScale, isNull);
    });

    test('copyWith clamps with the same rule the file does', () {
      final p = AppPrefs.initial.copyWith(crossfadeSeconds: 900);
      expect(p.crossfadeSeconds, 12);
      expect(
        AppPrefs.fromJson(p.toJson()).crossfadeSeconds,
        12,
        reason: 'a value written out and read back must be the value that was used',
      );
    });
  });

  group('keys that moved house', () {
    test('the old name of a switch still reads as that switch', () {
      expect(AppPrefs.fromJson(const {'prefer_music_videos': true}).officialOnly,
          isTrue);
      expect(AppPrefs.fromJson(const {'persona_layer': true}).bondsLayer, isTrue);
    });

    test('the new name wins when a file carries both', () {
      final p = AppPrefs.fromJson(
        const {'bonds_layer': false, 'persona_layer': true},
      );
      expect(p.bondsLayer, isFalse);
    });
  });

  group('the file a build writes', () {
    test('does not carry a key it has nothing to say about', () {
      final json = AppPrefs.initial.toJson();

      expect(json.containsKey('locale'), isFalse);
      expect(json.containsKey('palette'), isFalse,
          reason: 'the first palette is the default, not a stored choice');
      expect(json.containsKey('active_preset'), isFalse);
      expect(json['prefs_version'], 2);
    });

    test('carries every other key, so defaults are visible and diffable', () {
      final json = AppPrefs.initial.toJson();

      expect(json['resume_on_launch'], isFalse);
      expect(json['tab_animation'], isTrue);
      expect(json['layout_id'], 'persona');
      expect(json['palette'], isNull);
      expect(json['crossfade_seconds'], 0);
    });
  });

  group('the whole table', () {
    const everything = AppPrefs(
      resumeOnLaunch: true,
      crossfadeSeconds: 7,
      sleepTimerMinutes: 45,
      skipThresholdSeconds: 20,
      officialOnly: true,
      tabAnimation: false,
      showFps: true,
      checkForUpdates: false,
      locale: 'ja',
      weatherRefreshMinutes: 90,
      allowNetwork: false,
      contextWeather: true,
      contextClock: true,
      contextMix: true,
      placesEnabled: true,
      learnFromSkips: true,
      weatherVariants: true,
      autoSkin: true,
      recordHistory: false,
      bondsLayer: true,
      cycleCharacterArt: false,
      showVisualiser: false,
      showRomaji: false,
      dynamicByDefault: false,
      layoutId: 'glass',
      paletteIndex: 2,
      refillWhenQueueEnds: true,
      libraryIsGrid: true,
      activePresetId: 'p1',
      languageSkinId: 'mono',
      skinId: 'p5r',
      spectrumSmoothness: 60,
      spectrumScale: 150,
      spectrumShape: 'bars',
      searchOnline: true,
      playlistSort: 'added',
      pinnedPlaylistIds: ['a', 'b'],
      recentPlaylistIds: ['c'],
    );

    test('every key survives a trip through the file', () {
      final back = AppPrefs.fromJson(
        jsonDecode(jsonEncode(everything.toJson())) as Map<String, Object?>,
      );

      expect(back.resumeOnLaunch, isTrue);
      expect(back.crossfadeSeconds, 7);
      expect(back.sleepTimerMinutes, 45);
      expect(back.skipThresholdSeconds, 20);
      expect(back.officialOnly, isTrue);
      expect(back.tabAnimation, isFalse);
      expect(back.showFps, isTrue);
      expect(back.checkForUpdates, isFalse);
      expect(back.locale, 'ja');
      expect(back.weatherRefreshMinutes, 90);
      expect(back.allowNetwork, isFalse);
      expect(back.contextWeather, isTrue);
      expect(back.contextClock, isTrue);
      expect(back.contextMix, isTrue);
      expect(back.placesEnabled, isTrue);
      expect(back.learnFromSkips, isTrue);
      expect(back.weatherVariants, isTrue);
      expect(back.autoSkin, isTrue);
      expect(back.recordHistory, isFalse);
      expect(back.bondsLayer, isTrue);
      expect(back.cycleCharacterArt, isFalse);
      expect(back.showVisualiser, isFalse);
      expect(back.showRomaji, isFalse);
      expect(back.dynamicByDefault, isFalse);
      expect(back.layoutId, 'glass');
      expect(back.paletteIndex, 2);
      expect(back.refillWhenQueueEnds, isTrue);
      expect(back.libraryIsGrid, isTrue);
      expect(back.activePresetId, 'p1');
      expect(back.languageSkinId, 'mono');
      expect(back.skinId, 'p5r');
      expect(back.spectrumSmoothness, 60);
      expect(back.spectrumScale, 150);
      expect(back.spectrumShape, 'bars');
      expect(back.searchOnline, isTrue);
      expect(back.playlistSort, 'added');
      expect(back.pinnedPlaylistIds, ['a', 'b']);
      expect(back.recentPlaylistIds, ['c']);
    });

    test('a copy that changes nothing keeps everything', () {
      // This is the table's own coverage check: a key with no row is dropped by
      // copyWith, and the field it belongs to would come back as its default.
      final same = everything.copyWith();

      expect(same.toJson(), everything.toJson());
      expect(same.activePresetId, 'p1',
          reason: 'a copy must not quietly drop a preset reference');
      expect(same.pinnedPlaylistIds, ['a', 'b']);
    });

    test('changing one key touches only that key', () {
      final edited = everything.copyWith(crossfadeSeconds: 3);

      expect(edited.crossfadeSeconds, 3);
      final before = Map<String, Object?>.from(everything.toJson())
        ..remove('crossfade_seconds');
      final after = Map<String, Object?>.from(edited.toJson())
        ..remove('crossfade_seconds');
      expect(after, before);
    });

    test('clearing a nullable key is a word of its own, not a null argument', () {
      expect(everything.copyWith(locale: null).locale, 'ja',
          reason: 'null means "unchanged"');
      expect(everything.copyWith(clearLocale: true).locale, isNull);
      expect(everything.copyWith(clearPreset: true).activePresetId, isNull);
      expect(everything.copyWith(clearLanguageSkin: true).languageSkinId, isNull);
      expect(everything.copyWith(clearLibraryGrid: true).libraryIsGrid, isNull);
    });
  });
}
