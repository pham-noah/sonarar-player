library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/context/context_icons.dart';
import 'package:sonarar/context/weather_codes.dart';
import 'package:sonarar/theme/skin_policy.dart';

void main() {
  group('every band has a glyph, and no two share one', () {
    test('all five bands resolve', () {
      for (final band in ContextBand.values) {
        expect(bandIcon(band), isA<IconData>(), reason: '$band');
      }
    });

    test('a band icon is never the "no reading" placeholder', () {
      for (final band in ContextBand.values) {
        expect(bandIcon(band), isNot(Icons.hourglass_empty_rounded), reason: '$band');
      }
    });

    test('the bands are visually distinct from one another', () {
      final icons = {for (final b in ContextBand.values) bandIcon(b)};
      expect(icons.length, ContextBand.values.length,
          reason: 'two bands sharing a glyph makes the badge ambiguous');
    });

    test('no reading yet is the hourglass, which is not a band', () {
      expect(bandIcon(null), Icons.hourglass_empty_rounded);
      expect(ContextBand.values.any((b) => bandIcon(b) == Icons.hourglass_empty_rounded),
          isFalse);
    });
  });

  group('weather', () {
    test('every condition the app can be in has an icon', () {
      for (final c in WeatherCondition.values) {
        if (c == WeatherCondition.unknown) continue;
        expect(weatherIcon(c), isNotNull, reason: '$c');
      }
    });

    test('OVERCAST is not silence — the bug he reported', () {
      expect(weatherIcon(WeatherCondition.clouds), isNotNull);
    });

    test('unknown draws NOTHING, because no reading is not clear weather', () {
      expect(weatherIcon(WeatherCondition.unknown), isNull);
    });

    test('the conditions are visually distinct', () {
      final icons = {
        for (final c in WeatherCondition.values)
          if (weatherIcon(c) != null) weatherIcon(c)!,
      };
      expect(icons.length, WeatherCondition.values.length - 1,
          reason: 'two conditions sharing a glyph makes the badge ambiguous');
    });

    test('weather and band glyphs do not collide with each other', () {
      final bandGlyphs = {for (final b in ContextBand.values) bandIcon(b)};
      final skyGlyphs = {
        for (final c in WeatherCondition.values)
          if (weatherIcon(c) != null) weatherIcon(c)!,
      };
      expect(bandGlyphs.intersection(skyGlyphs), isEmpty);
    });
  });
}
