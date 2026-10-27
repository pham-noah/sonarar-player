library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/library/weather_variants.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id, String title, {String? of, String? tag}) => Track(
      id: id,
      title: title,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '$id.jpg',
      gainDb: null,
      variantOf: of,
      variantTag: tag);

List<Track> _lib() => [
      _t('mask', 'Beneath the Mask'),
      _t('mask-rain', 'Beneath the Mask -rain', of: 'mask', tag: 'rain'),
      _t('life', 'Life Will Change'),
      _t('life-rain', 'Life Will Change -rain', of: 'life', tag: 'rain'),
      _t('plain', 'A Song With No Rain Version'),
    ];

void main() {
  group('weatherVariantTag', () {
    test('rain calls for the rain cut', () {
      expect(weatherVariantTag(sky: Sky.rain), 'rain');
    });

    test('snow calls for the snow cut, the same way rain does', () {
      expect(weatherVariantTag(sky: Sky.snow), 'snow');
    });

    test('snow outranks rain, since a reading of both is snowing', () {
      expect(weatherVariantTag(sky: Sky.snow), 'snow');
    });

    test('clear weather calls for nothing', () {
      expect(weatherVariantTag(sky: Sky.unknown), isNull);
    });
  });

  group('situationVariantTag — his precedence order', () {
    test('at home asks for the LONG cut', () {
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.home),
        'long');
    });

    test('commuting asks for the SHORT cut', () {
      expect(
        situationVariantTag(sky: Sky.unknown, whereabouts: Whereabouts.commuting),
        'short');
    });

    test('weather BEATS the place rules', () {
      expect(
        situationVariantTag(
            sky: Sky.rain, whereabouts: Whereabouts.commuting),
        'rain');
    });

    test('snow beats rain, and both beat the place rules', () {
      expect(
        situationVariantTag(
            sky: Sky.snow, whereabouts: Whereabouts.commuting),
        'snow');
    });

    test('commuting beats at home, which is the order he named them in', () {
      expect(
        situationVariantTag(
            sky: Sky.unknown, whereabouts: Whereabouts.commuting),
        'short');
    });

    test('nothing true asks for nothing', () {
      expect(situationVariantTag(sky: Sky.unknown), isNull);
    });

    test('weatherVariantTag still answers the weather alone', () {
      expect(weatherVariantTag(sky: Sky.rain), 'rain');
      expect(weatherVariantTag(sky: Sky.unknown), isNull);
    });
  });

  group('planWeatherVariants', () {
    test('the playing song is REPLACED with its rain cut', () {
      final lib = _lib();
      final queue = [lib[0], lib[2], lib[4]];
      final plan = planWeatherVariants(
        queue: queue,
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);

      expect(plan.replaceCurrent?.id, 'mask-rain');
      expect(plan.replacedFrom?.id, 'mask', reason: 'so the way back is known');
    });

    test('the OTHER songs with a rain cut are ADDED', () {
      final lib = _lib();
      final queue = [lib[0], lib[2], lib[4]];
      final plan = planWeatherVariants(
        queue: queue,
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);

      expect(plan.add.map((t) => t.id), ['life-rain']);
    });

    test('a track already playing its rain cut is not swapped for itself', () {
      final lib = _lib();
      final queue = [lib[1], lib[2]];
      final plan = planWeatherVariants(
        queue: queue,
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);
      expect(plan.replaceCurrent, isNull);
    });

    test('a track with NO rain version is left exactly as it is', () {
      final lib = _lib();
      final queue = [lib[4]];
      final plan = planWeatherVariants(
        queue: queue,
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);
      expect(plan.isEmpty, isTrue);
    });

    test('clear weather does nothing', () {
      final lib = _lib();
      final plan = planWeatherVariants(
        queue: [lib[0], lib[2]],
        currentIndex: 0,
        library: lib,
        sky: Sky.unknown);
      expect(plan.isEmpty, isTrue);
    });

    test('an empty queue does nothing rather than throwing', () {
      final plan = planWeatherVariants(
        queue: const [],
        currentIndex: 0,
        library: _lib(),
        sky: Sky.rain);
      expect(plan.isEmpty, isTrue);
    });

    test('the added cut is not added twice when it is already queued', () {
      final lib = _lib();

      final queue = [lib[0], lib[1], lib[2]];
      final plan = planWeatherVariants(
        queue: queue,
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);
      expect(plan.add.map((t) => t.id), ['life-rain']);
    });

    test('the replaced track is never also in the added list', () {
      final lib = _lib();
      final plan = planWeatherVariants(
        queue: [lib[0], lib[2]],
        currentIndex: 0,
        library: lib,
        sky: Sky.rain);
      expect(
        plan.add.any((t) => t.id == plan.replaceCurrent?.id),
        isFalse,
        reason: 'the same recording cannot be both swapped in and queued behind');
    });
  });
}
