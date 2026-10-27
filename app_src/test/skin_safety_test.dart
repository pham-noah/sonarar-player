library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/art/skin_art.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  test('every skin in the picker resolves its art without throwing', () {
    for (final skin in kAllSkins) {
      expect(() => artFor(skin.id), returnsNormally,
          reason: '${skin.displayName} crashed on selection');
    }
  });

  test('a skin with no art gets an EMPTY set, not a broken one', () {
    final empty = artFor(SkinId.minimal);
    expect(empty.hasArt, isFalse);
    expect(empty.pieces, isEmpty);
  });

  test('the Persona skins resolve with NO art on this branch, and do not throw', () {
    for (final id in [SkinId.abyss, SkinId.amber, SkinId.crimson]) {
      expect(() => artFor(id), returnsNormally, reason: '$id crashed without art');
      expect(artFor(id).hasArt, isFalse, reason: '$id still declares art');
    }
  });

  test('no two skins share an id', () {
    final ids = {for (final s in kAllSkins) s.id};
    expect(ids.length, kAllSkins.length);
  });

  test('the non-Persona skins do not slant, or slant gently', () {
    expect(kSkinMinimal.skewDegrees, 0);
    expect(kSkinMono.skewDegrees, 0);
    expect(kSkinBloom.skewDegrees, greaterThan(0));
    expect(kSkinBloom.skewDegrees, lessThan(kSkinAmber.skewDegrees));
  });

  test('every skin has readable text against its own background', () {
    double lum(Color c) =>
        0.2126 * (c.r) + 0.7152 * (c.g) + 0.0722 * (c.b);
    for (final s in kAllSkins) {
      final gap = (lum(s.textPrimary) - lum(s.background)).abs();
      expect(gap, greaterThan(0.4),
          reason: '${s.displayName}: text and background are too close to read');
    }
  });
}
