library;

import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/surface.dart';

/// A panel is read, not looked through.
///
/// The glass sheets were translucent enough that a bright cover behind them came
/// through the text. The fix is a floor on the panel role's own alpha, and this pins
/// it: over WHITE — the worst backdrop there is — the panel still shows its own colour.
double _linear(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a) + 0.05;
  final lb = _luminance(b) + 0.05;
  return la > lb ? la / lb : lb / la;
}

void main() {
  test('a Glass panel is the room under its wash, not a white film', () {
    final presentation = presentationFor(LayoutKind.glass, kSkinCrimson);
    final pal = presentation.palette;

    final tint = Surface.glassTintFor(pal, SurfaceRole.panel, pal.surface);

    // `surface` in this palette is white at 20%. Held at the floor as-is it makes a
    // pale sheet; carried over the room's own colour it stays a dark one.
    expect(tint.a, greaterThanOrEqualTo(0.94),
        reason: 'a panel is read, not looked through');
    expect(
      _luminance(tint),
      lessThan(_luminance(pal.textPrimary) * 0.25),
      reason: 'the sheet is still light enough for near-white text to vanish',
    );
  });

  test('both glass skins keep AA text on their panel', () {
    for (final skin in kAllSkins) {
      final presentation = presentationFor(LayoutKind.glass, skin);
      final pal = presentation.palette;
      final tint = Surface.glassTintFor(pal, SurfaceRole.panel, pal.surface);
      final sheet = Color.alphaBlend(tint, pal.background);

      expect(_contrast(pal.textPrimary, sheet), greaterThan(4.5),
          reason: '${skin.id.name}: panel text does not reach AA');
    }
  });
}
