library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_focus.dart';
import 'package:sonarar/art/skin_art.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

(int, int)? _readImageSize(List<int> bytes) {
  if (bytes.length > 24 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    int be32(int at) =>
        (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3];
    return (be32(16), be32(20));
  }
  if (bytes.length > 4 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];

      final isSof = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (isSof) {
        return (
          (bytes[i + 7] << 8) | bytes[i + 8],
          (bytes[i + 5] << 8) | bytes[i + 6]);
      }
      i += 2 + len;
    }
  }
  return null;
}

Matcher _closeTo3(double want) => closeTo(want, 0.0005);

void main() {
  const policy = SkinPolicy();

  group('context bands', () {
    test('midnight is Dark Hour, and only midnight', () {
      expect(policy.bandFor(0), ContextBand.darkHour);
      expect(policy.bandFor(1), isNot(ContextBand.darkHour));
      expect(policy.bandFor(23), isNot(ContextBand.darkHour));
    });

    test('the day splits the way the games split it', () {
      expect(policy.bandFor(8), ContextBand.morning);
      expect(policy.bandFor(14), ContextBand.afternoon);
      expect(policy.bandFor(19), ContextBand.evening);
      expect(policy.bandFor(22), ContextBand.night);
      expect(policy.bandFor(3), ContextBand.night);
    });

    test('every hour of the day resolves to a band', () {
      for (var h = 0; h < 24; h++) {
        expect(policy.bandFor(h), isNotNull, reason: 'hour $h');
      }
    });
  });

  group('skin follows context', () {
    test('Dark Hour forces P3R even when it is raining', () {
      final ctx = PlayContext(
        band: policy.bandFor(0),
        whereabouts: Whereabouts.home,
        sky: Sky.rain,
        localHour: 0);
      expect(policy.skinForContext(ctx), SkinId.abyss);
      expect(ctx.isDarkHour, isTrue);
    });

    test('rain is a P4R trigger regardless of hour', () {
      final ctx = PlayContext(
        band: ContextBand.night,
        sky: Sky.rain,
        localHour: 23);
      expect(policy.skinForContext(ctx), SkinId.amber);
    });

    test('clear night is P5R, clear morning is P4R', () {
      expect(
        policy.skinForContext(const PlayContext(
          band: ContextBand.night, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 22)),
        SkinId.crimson);
      expect(
        policy.skinForContext(const PlayContext(
          band: ContextBand.morning, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 9)),
        SkinId.amber);
    });
  });

  group('manual override', () {
    const pref = SkinPreference(manualSkin: SkinId.crimson);

    test('a manual pick wins while the band is unchanged', () {
      const ctx = PlayContext(
        band: ContextBand.night, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 22);
      expect(
        policy.resolve(ctx: ctx, pref: pref, previousCtx: ctx),
        SkinId.crimson);
    });

    test('context reasserts itself once the band changes', () {
      const before = PlayContext(
        band: ContextBand.evening, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 20);
      const after = PlayContext(
        band: ContextBand.morning, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 9);
      expect(
        policy.resolve(ctx: after, pref: pref, previousCtx: before),
        SkinId.amber);
    });

    test('no manual pick means context always rules', () {
      const ctx = PlayContext(
        band: ContextBand.evening, whereabouts: Whereabouts.home, sky: Sky.unknown, localHour: 19);
      expect(
        policy.resolve(ctx: ctx, pref: const SkinPreference()),
        SkinId.abyss);
    });
  });

  group('skin art', () {
    test('every GAME skin resolves with NO art on this branch, and none of them throw', () {
      for (final skin in [kSkinAbyss, kSkinAmber, kSkinCrimson, kSkinMinimal]) {
        final artSet = artFor(skin.id);
        expect(artSet.hasArt, isFalse, reason: '${skin.id} still declares art');
        expect(artSet.defaultArt, isNull);
        expect(artSet.pieces, isEmpty);
      }
    });

    test('an empty art set is inert rather than a crash', () {
      const empty = SkinArtSet(SkinId.amber, []);
      expect(empty.hasArt, isFalse);
      expect(empty.defaultArt, isNull);
      expect(empty.atOrNull(0), isNull);
      expect(empty.nextIndex(0), 0);
      expect(empty.previousIndex(7), 0);
    });

    test('NEXT advances and wraps', () {
      for (final artSet in kAllArtSets) {
        var i = 0;
        for (var step = 0; step < artSet.length; step++) {
          expect(i, step);
          i = artSet.nextIndex(i);
        }
        expect(i, 0, reason: 'should have wrapped back to the default');
      }
    });

    test('PREVIOUS is the inverse of NEXT', () {
      for (final artSet in kAllArtSets) {
        for (var i = 0; i < artSet.length; i++) {
          expect(artSet.previousIndex(artSet.nextIndex(i)), i);
        }
      }
    });

    test('cycling never escapes the art set bounds', () {
      final r = kArtCrimson;
      var i = 0;
      for (var n = 0; n < 200; n++) {
        i = r.nextIndex(i);
        expect(i, inInclusiveRange(0, r.length - 1));
      }
    });

    test('keys are unique, and every asset lives in its own skin folder', () {
      for (final artSet in kAllArtSets) {
        final keys = artSet.pieces.map((m) => m.key).toList();
        expect(keys.toSet().length, keys.length, reason: 'duplicate key in ${artSet.skinId}');
        for (final m in artSet.pieces) {
          expect(m.assetPath.split('/').last, startsWith('${m.key}.'),
              reason: '${m.assetPath} does not match its key ${m.key}');

          expect(m.assetPath, startsWith('assets/art/${artSet.skinId.name}/'));
        }
      }
    });

    test('P4R\'s art is whole screens, not figures', () {
      for (final piece in kArtAmber.pieces) {
        expect(piece.fullBleed, isTrue, reason: piece.key);
      }

      for (final piece in [...kArtAbyss.pieces, ...kArtCrimson.pieces]) {
        expect(piece.fullBleed, isFalse, reason: piece.key);
      }
    });

    test('every declared aspect matches the real file', () {
      for (final piece in kAllArtPieces) {
        final file = File(piece.assetPath);
        expect(file.existsSync(), isTrue,
            reason: 'no file for ${piece.key} at ${piece.assetPath}');
        final size = _readImageSize(file.readAsBytesSync());
        expect(size, isNotNull, reason: 'unreadable image: ${piece.assetPath}');
        final (w, h) = size!;
        expect(
          piece.aspect,
          _closeTo3(w / h),
          reason: '${piece.key} declares aspect ${piece.aspect} but the file '
              'is ${w}x$h (${w / h})');
      }
    });

    test('framing defaults are inside the range the frame can honour', () {
      for (final piece in kAllArtPieces) {
        expect(piece.focus.dx, inInclusiveRange(-1.0, 1.0), reason: piece.key);
        expect(piece.focus.dy, inInclusiveRange(-1.0, 1.0), reason: piece.key);
        expect(piece.focus.zoom, inInclusiveRange(kMinArtZoom, kMaxArtZoom),
            reason: piece.key);

        expect(piece.focus.zoom, kMinArtZoom, reason: piece.key);
      }
    });

    test('defaults are per piece, not one shared value', () {
      for (final set in [kArtAbyss, kArtCrimson]) {
        final xs = set.pieces.map((p) => p.focus.dx).toSet();
        expect(xs.length, greaterThan(1),
            reason: '${set.skinId} has one shared dx across every piece');
      }

      expect(kArtAbyss.byKey('makoto')!.focus.dx, closeTo(0.56, 0.001));
      expect(kArtAbyss.byKey('mitsuru')!.focus.dx, closeTo(-0.56, 0.001));
    });

    test('byKey finds a piece, and returns null for one that is gone', () {
      expect(kArtAbyss.byKey('yukari')?.key, 'yukari');
      expect(kArtAbyss.indexOfKey('yukari'), 1);
      expect(kArtAbyss.byKey('nobody'), isNull);
      expect(kArtAbyss.indexOfKey('nobody'), -1);
      expect(kArtAbyss.byKey(''), isNull);
    });
  });

  group('skin invariants', () {
    test('every skin clears the contrast floor for body text', () {
      for (final skin in kAllSkins) {
        final ratio = _contrast(skin.textPrimary, skin.background);
        expect(ratio, greaterThanOrEqualTo(7.0),
            reason: '${skin.displayName} primary text ratio $ratio');
        final secondary = _contrast(skin.textSecondary, skin.background);
        expect(secondary, greaterThanOrEqualTo(4.5),
            reason: '${skin.displayName} secondary text ratio $secondary');
      }
    });

    test('text drawn on the accent fill is legible there too', () {
      for (final skin in kAllSkins) {
        final ratio = _contrast(skin.onAccent, skin.accent);
        expect(ratio, greaterThanOrEqualTo(3.0),
            reason: '${skin.displayName} on-accent ratio $ratio');
      }
    });

    test('P5R keeps red as an accent and never as body text', () {
      expect(kSkinCrimson.textPrimary, isNot(kSkinCrimson.accent));
      expect(kSkinCrimson.textSecondary, isNot(kSkinCrimson.accent));
    });

    test('P3R and P5R share an angle; P4R is deliberately softer', () {
      expect(kSkinAbyss.skewDegrees, kSkinCrimson.skewDegrees);
      expect(kSkinAmber.skewDegrees, lessThan(kSkinAbyss.skewDegrees));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _luminance(Color c) {
  double channel(double v) {
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}
