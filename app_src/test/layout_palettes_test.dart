library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

double _lum(Color c) {
  double f(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('every layout palette is readable', () {
    const floor = 4.5;

    for (final named in [...kSolidPalettes, ...kGlassPalettes]) {
      test('${named.name}: secondary ink clears the floor', () {
        final p = named.palette;
        final onBg = _contrast(p.textSecondary, p.background);

        final onFill = p.pageFill == null
            ? onBg
            : _contrast(p.textSecondary, p.pageFill!);
        final worst = math.min(onBg, onFill);
        expect(worst, greaterThanOrEqualTo(floor),
            reason: '${named.name} secondary text is ${worst.toStringAsFixed(2)}:1 '
                'against a $floor:1 floor');
      });

      test('${named.name}: primary ink and the accent are strongly readable', () {
        final p = named.palette;
        expect(_contrast(p.textPrimary, p.background), greaterThanOrEqualTo(floor));

        expect(_contrast(p.accent, p.background), greaterThanOrEqualTo(3.0),
            reason: '${named.name} accent does not separate from its ground');
        expect(_contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
            reason: '${named.name} text ON the accent fill is unreadable');
      });
    }
  });

  group('the palettes belong to the layout', () {
    test('Solid and Glass each bring three, and they are DIFFERENT patterns', () {
      expect(kSolidPalettes.length, 3);
      expect(kGlassPalettes.length, 3);

      final solidAccents = kSolidPalettes.map((n) => n.palette.accent).toSet();
      final glassAccents = kGlassPalettes.map((n) => n.palette.accent).toSet();
      expect(solidAccents.length, 3);
      expect(glassAccents.length, 3);
    });

    test('the current patterns are still first, so nothing about the default moved', () {
      expect(kSolidPalettes.first.palette.background, const Color(0xFF121212));
      expect(kSolidPalettes.first.palette.accent, const Color(0xFF1DB954));
      expect(kGlassPalettes.first.palette.accent, const Color(0xFF7FD1FF));
    });

    test('Persona ignores the index — its palettes are its six skins', () {
      final p = presentationFor(LayoutKind.persona, kSkinCrimson, paletteIndex: 2);
      expect(p.palette.accent, kSkinCrimson.accent);
    });

    test('a stale index WRAPS rather than throwing', () {
      final p = presentationFor(LayoutKind.solid, kSkinCrimson, paletteIndex: 2);
      expect(p.palette.accent, kSolidPalettes[2].palette.accent);

      final wrapped = presentationFor(LayoutKind.solid, kSkinCrimson, paletteIndex: 5);
      expect(wrapped.palette.accent, kSolidPalettes[2].palette.accent);
    });
  });
}
