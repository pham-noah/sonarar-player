library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/widgets/spectrum.dart' show SpectrumShape;

void main() {
  group('the smoothness setting', () {
    test('an install that never touched it gets the old hard-coded 0.35', () {
      expect(const AppPrefs().spectrumSmoothness, isNull);
      expect(const AppPrefs().spectrumEase, closeTo(0.35, 1e-9));
    });

    test('it survives a round trip through the file', () {
      const saved = AppPrefs(spectrumSmoothness: 70);
      expect(AppPrefs.fromJson(saved.toJson()).spectrumSmoothness, 70);
      expect(AppPrefs.fromJson(saved.toJson()).spectrumEase, closeTo(0.7, 1e-9));
    });

    test('the ends of the dial mean what they say', () {
      expect(const AppPrefs(spectrumSmoothness: 0).spectrumEase, 0.0);
      expect(const AppPrefs(spectrumSmoothness: 100).spectrumEase, 1.0);
    });

    test('an out-of-range number is clamped, not obeyed', () {
      expect(const AppPrefs(spectrumSmoothness: 400).spectrumEase, 1.0);
      expect(const AppPrefs(spectrumSmoothness: -50).spectrumEase, 0.0);

      expect(AppPrefs.fromJson(const {'spectrum_smoothness': 900}).spectrumEase, 1.0);
      expect(AppPrefs.fromJson(const {'spectrum_smoothness': -900}).spectrumEase, 0.0);
    });

    test('a non-integer or absent value falls back to the default', () {
      expect(AppPrefs.fromJson(const {'spectrum_smoothness': 'loud'}).spectrumEase,
          closeTo(0.35, 1e-9));
      expect(AppPrefs.fromJson(const <String, Object?>{}).spectrumEase,
          closeTo(0.35, 1e-9));
    });

    test('a copyWith that does not mention it leaves it alone', () {
      const worn = AppPrefs(spectrumSmoothness: 60);
      expect(worn.copyWith(showFps: true).spectrumSmoothness, 60);
      expect(worn.copyWith(spectrumSmoothness: 20).spectrumSmoothness, 20);

      expect(worn.copyWith(spectrumSmoothness: 500).spectrumSmoothness, 100);
    });
  });

  group('SPECTRUM SCALE', () {
    test('an install that never touched it draws the 110px it always did', () {
      expect(const AppPrefs().spectrumScale, isNull);
      expect(AppPrefs.defaultScalePercent, 100);
    });

    test('the percent survives a round trip and is clamped at both ends', () {
      expect(AppPrefs.fromJson(const AppPrefs(spectrumScale: 150).toJson())
          .spectrumScalePercent, 150);

      expect(const AppPrefs(spectrumScale: 5).spectrumScalePercent, 40);
      expect(const AppPrefs(spectrumScale: 999).spectrumScalePercent, 220);
      expect(AppPrefs.fromJson(const {'spectrum_scale': -10}).spectrumScalePercent, 40);
      expect(AppPrefs.fromJson(const {'spectrum_scale': 'wide'}).spectrumScalePercent,
          100);
    });
  });

  group('SPECTRUM SHAPE', () {
    test('an install that never touched it keeps the rounded bar it always had', () {
      expect(const AppPrefs().spectrumShape, isNull);
      expect(const AppPrefs().spectrumShapeName, 'rounded');
      expect(SpectrumShape.byName(null), SpectrumShape.rounded);
    });

    test('every shape is offered, and SQUARE — the one he asked for — is among them', () {
      expect(SpectrumShape.values, contains(SpectrumShape.square));
      expect(SpectrumShape.values.length, greaterThanOrEqualTo(4));
      for (final s in SpectrumShape.values) {
        expect(SpectrumShape.byName(s.name), s, reason: 'byName lost ${s.name}');
        expect(s.label, isNotEmpty);
      }
    });

    test('an unknown name degrades to the default rather than crashing', () {
      expect(AppPrefs.fromJson(const {'spectrum_shape': 'hexagon'})
          .spectrumShapeName, 'hexagon');
      expect(SpectrumShape.byName('hexagon'), SpectrumShape.rounded);
    });

    test('it survives a round trip through the file', () {
      const saved = AppPrefs(spectrumShape: 'pill');
      expect(AppPrefs.fromJson(saved.toJson()).spectrumShapeName, 'pill');
    });
  });

  group('the painter takes the ease as a value, defaulting to the old constant', () {
    test('the default the widget declares is the 0.35 the painter used to hard-code', () {
      expect(AppPrefs.defaultSmoothnessPercent, 35);
      expect(const AppPrefs().spectrumEase, closeTo(0.35, 1e-9));
    });
  });
}
