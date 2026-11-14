library;

// The colour ladder, measured rather than eyeballed.
//
// P0-1 hangs on three derived roles: `textMuted` (4.5:1 against its own page),
// `accentInk` (the accent as text, 4.5:1) and `borderStrong` (a control's edge,
// 3:1). They are computed, not tabulated, because `withAccent`/`withBase` mint
// skins at runtime from colours nobody listed. This is the test that keeps the
// computation honest on every shipped skin *and* every shipped palette.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/contrast.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

/// What a translucent ink looks like once it is on the page.
Color flat(Color ink, Color page) => Color.alphaBlend(ink, page);

void main() {
  final pages = <String, (Color bg, Color muted, Color ink, Color border)>{
    for (final s in kAllSkins)
      'skin ${s.id.name}': (
        s.background,
        s.textMuted,
        s.accentInk,
        s.borderStrong
      ),
    for (final n in <NamedPalette>[...kSolidPalettes, ...kGlassPalettes])
      'palette ${n.name}': (
        n.palette.background,
        n.palette.textMuted,
        n.palette.accentInk,
        n.palette.borderStrong
      ),
  };

  test('there are nine themes to check', () {
    // Six skins and six layout palettes, two of which share a base colour with
    // the Sonar themes. A palette added later is covered by the loop above.
    expect(kAllSkins.length, 6);
    expect(kSolidPalettes.length + kGlassPalettes.length, 6);
  });

  group('muted text clears 4.5:1', () {
    for (final entry in pages.entries) {
      test(entry.key, () {
        final (bg, muted, _, _) = entry.value;
        final ratio = contrastRatio(flat(muted, bg), bg);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: textMuted is ${ratio.toStringAsFixed(2)}:1');
      });
    }
  });

  group('accent used as ink clears 4.5:1', () {
    for (final entry in pages.entries) {
      test(entry.key, () {
        final (bg, _, ink, _) = entry.value;
        final ratio = contrastRatio(ink, bg);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: accentInk is ${ratio.toStringAsFixed(2)}:1');
      });
    }
  });

  group('a control edge clears 3:1', () {
    for (final entry in pages.entries) {
      test(entry.key, () {
        final (bg, _, _, border) = entry.value;
        final ratio = contrastRatio(flat(border, bg), bg);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '${entry.key}: borderStrong is ${ratio.toStringAsFixed(2)}:1');
      });
    }
  });

  test('the light skins get the ink they need, not the accent they had', () {
    // The two measured failures from the audit: the accent on Minimal is
    // 1.88:1 as text, and the muted ladder could not reach 4.5:1 at all.
    final minimal = skinFor(SkinId.minimal);
    expect(contrastRatio(minimal.accent, minimal.background),
        lessThan(2.0),
        reason: 'if the raw accent is legible here, this test has stopped testing anything');
    expect(contrastRatio(minimal.accentInk, minimal.background),
        greaterThanOrEqualTo(4.5));
    expect(minimal.mutedFloor, greaterThan(0.85));

    final bloom = skinFor(SkinId.bloom);
    expect(contrastRatio(bloom.accentInk, bloom.background),
        greaterThanOrEqualTo(4.5));
    expect(bloom.mutedFloor, greaterThan(0.85));
  });

  test('secondary(a) cannot be asked below the floor', () {
    for (final skin in kAllSkins) {
      final asked = skin.secondary(0.1);
      final ratio =
          contrastRatio(flat(asked, skin.background), skin.background);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: '${skin.id.name}: secondary(0.1) came back at '
              '${ratio.toStringAsFixed(2)}:1');
    }
  });

  test('a minted skin keeps the ladder', () {
    // withAccent/withBase are how the user's own colours arrive; the floors
    // must hold for them too, or the feature is a way to build an illegible app.
    final minted = skinFor(SkinId.minimal).withAccent(const Color(0xFFB9C7D9));
    expect(contrastRatio(minted.accentInk, minted.background),
        greaterThanOrEqualTo(4.5));
    final rebased = skinFor(SkinId.abyss).withBase(const Color(0xFFF2EFE9));
    expect(contrastRatio(flat(rebased.textMuted, rebased.background),
            rebased.background),
        greaterThanOrEqualTo(4.5));
  });
}
