library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/layout_kit.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/surface.dart' show SurfaceRole;

void main() {
  group('every layout has exactly one kit, and it is reachable from the enum', () {
    test('all three resolve, with distinct ids', () {
      expect(LayoutKind.persona.kit.id, 'persona');
      expect(LayoutKind.solid.kit.id, 'solid');
      expect(LayoutKind.glass.kit.id, 'glass');
      expect(
        LayoutKind.values.map((k) => k.kit.id).toSet(),
        hasLength(LayoutKind.values.length),
        reason: 'two layouts sharing a kit would make them identical',
      );
    });

    test('the kit reaches the presentation, so a screen never has to re-derive it', () {
      for (final kind in LayoutKind.values) {
        final p = presentationFor(kind, kSkinAbyss);
        expect(p.kit.id, kind.kit.id,
            reason: '$kind resolved a presentation from a different kit — the '
                'one place that says what a layout is was bypassed');
      }
    });
  });

  group('the shell frame — the structural difference, in one field', () {
    test('persona docks its bars, the plain layouts float them', () {
      expect(LayoutKind.persona.kit.chrome.shellFrame, ShellFrame.docked);
      expect(LayoutKind.solid.kit.chrome.shellFrame, ShellFrame.floating);
      expect(LayoutKind.glass.kit.chrome.shellFrame, ShellFrame.floating);
    });

    test('docking is what makes clearance necessary — a docked bar takes real height', () {
      expect(LayoutKind.persona.kit.arrangement.tabBarInsets, EdgeInsets.zero);

      expect(LayoutKind.solid.kit.arrangement.tabBarInsets.bottom, greaterThan(0));
      expect(LayoutKind.solid.kit.arrangement.bottomClearance,
          greaterThan(LayoutKind.persona.kit.arrangement.bottomClearance));
    });
  });

  group('the material — what Surface used to decide with seven isPersona branches', () {
    test('persona slants its surfaces and carries the heavy accent edge', () {
      final m = LayoutKind.persona.kit.material;
      expect(m.slant, isTrue);
      expect(m.edge, SurfaceEdge.heavy);
      expect(m.activeFillIsAccent, isTrue);
      expect(m.blur, 0, reason: 'Persona is opaque, so no BackdropFilter is allocated');
      expect(m.specularEdge, isFalse);
    });

    test('persona keeps one small radius whatever the role', () {
      final radii = LayoutKind.persona.kit.material.radii;
      for (final role in SurfaceRole.values) {
        expect(radii[role], 4.0, reason: '$role moved off Persona\'s stamp radius');
      }
    });

    test('solid is flat BY DESIGN: no blur, no specular edge, no cast shadow', () {
      final m = LayoutKind.solid.kit.material;
      expect(m.slant, isFalse);
      expect(m.blur, 0);
      expect(m.specularEdge, isFalse);
      expect(m.castShadow, isFalse,
          reason: 'Solid is flat by design — its palette declares a transparent shadow and the '
              'hairline does the work. The first version of this said !isPersona, which handed Solid a '
              'shadow too, and layout_axis_test caught it');
    });

    test('glass floats: blurred, specular, and it casts', () {
      final m = LayoutKind.glass.kit.material;
      expect(m.blur, greaterThan(0));
      expect(m.specularEdge, isTrue);
      expect(m.castShadow, isTrue);
      expect(m.slant, isFalse);
    });

    test('glass shares Solid\'s arrangement and restraint — the material is the difference', () {
      expect(LayoutKind.glass.kit.arrangement.libraryIsGrid,
          LayoutKind.solid.kit.arrangement.libraryIsGrid);
      expect(LayoutKind.glass.kit.chrome.shellFrame,
          LayoutKind.solid.kit.chrome.shellFrame);
      expect(LayoutKind.glass.kit.material.blur,
          isNot(LayoutKind.solid.kit.material.blur),
          reason: 'if this were equal the two layouts would be the same thing');
    });

    test('only persona fills an inactive slab with nothing', () {
      expect(LayoutKind.persona.kit.material.transparentInactiveFill, isTrue);
      expect(LayoutKind.solid.kit.material.transparentInactiveFill, isFalse);
      expect(LayoutKind.glass.kit.material.transparentInactiveFill, isFalse);
    });
  });

  group('the chrome — which devices are drawn, and in what form', () {
    test('persona draws its banner heading; the plain layouts draw the mark', () {
      expect(LayoutKind.persona.kit.chrome.sectionBand, SectionBandForm.banner);
      expect(LayoutKind.solid.kit.chrome.sectionBand, SectionBandForm.mark);
      expect(LayoutKind.glass.kit.chrome.sectionBand, SectionBandForm.mark);
    });

    test('persona draws the personality layer the plain layouts do not', () {
      final p = LayoutKind.persona.kit.chrome;
      expect(p.wordmark, isTrue);
      expect(p.hemisphereScrim, isTrue);
      expect(p.transportTilt, isNot(0));
      expect(p.upNextStrip, isFalse);

      final plain = LayoutKind.solid.kit.chrome;
      expect(plain.wordmark, isFalse);
      expect(plain.hemisphereScrim, isFalse);
      expect(plain.transportTilt, 0);
      expect(plain.upNextStrip, isTrue);
    });

    test('persona shows art on its own; the plain layouts wait to be asked', () {
      expect(LayoutKind.persona.kit.chrome.artByDefault, isTrue);
      expect(LayoutKind.solid.kit.chrome.artByDefault, isFalse,
          reason: 'a P5R figure behind a green page reads as a Persona layout '
              'wearing green');
    });

    test('the plain layouts reach their art behind the floating bars; persona does not', () {
      expect(LayoutKind.persona.kit.chrome.artReachBehindBars, 0);
      expect(LayoutKind.solid.kit.chrome.artReachBehindBars, lessThan(0));
      expect(LayoutKind.persona.kit.chrome.backdropReach, 0);
      expect(LayoutKind.solid.kit.chrome.backdropReach, lessThan(0));
    });

    test('the player\'s cover is the subject on persona and a caption on the plain layouts', () {
      expect(LayoutKind.persona.kit.chrome.coverSize, 156);
      expect(LayoutKind.solid.kit.chrome.coverSize, 88);
    });

    test('the scrubber side is a real difference, not an accident', () {
      expect(LayoutKind.persona.kit.chrome.scrubberBelowTransport, isTrue);
      expect(LayoutKind.solid.kit.chrome.scrubberBelowTransport, isFalse);
    });
  });

  group('the palette — persona derives it, the plain layouts bring their own', () {
    test('persona\'s kit has no palette of its own, and that is the point', () {
      expect(LayoutKind.persona.kit.palette, isNull);
    });

    test('a persona presentation\'s palette IS the skin\'s', () {
      final p = presentationFor(LayoutKind.persona, kSkinCrimson);
      expect(p.palette.accent, kSkinCrimson.accent);
      expect(p.palette.background, kSkinCrimson.background);
    });

    test('the plain layouts carry their named palettes on the kit', () {
      expect(LayoutKind.solid.kit.palettes, isNotEmpty);
      expect(LayoutKind.glass.kit.palettes, isNotEmpty);
      expect(LayoutKind.persona.kit.palettes, isEmpty,
          reason: 'Persona\'s palettes ARE its skins — a second list would be two pickers for one choice');
    });

    test('the palette index is honoured through the kit, wrapping rather than clamping', () {
      final a = presentationFor(LayoutKind.solid, kSkinAbyss, paletteIndex: 0);
      final b = presentationFor(LayoutKind.solid, kSkinAbyss, paletteIndex: 1);
      final wrapped =
          presentationFor(LayoutKind.solid, kSkinAbyss, paletteIndex: 99);
      expect(a.kit.palette!.accent, isNot(b.kit.palette!.accent));
      expect(wrapped.kit.palette!.accent, a.kit.palette!.accent,
          reason: 'an out-of-range index must wrap, not throw');
    });

    test('withPalette copies the recipe rather than rebuilding it', () {
      final base = kSolidKit;
      final other = base.withPalette(base.palettes[1].palette);
      expect(other.material, base.material);
      expect(other.chrome, base.chrome);
      expect(other.arrangement, base.arrangement);
      expect(other.motion, base.motion);
      expect(other.palette, isNot(equals(base.palettes[0].palette)));
    });
  });

  group('what the kit MUST NOT do', () {
    test('persona resolves identically through forSkin and through presentationFor', () {
      final viaForSkin = Presentation.forSkin(kSkinAbyss);
      final viaFor = presentationFor(LayoutKind.persona, kSkinAbyss);
      expect(viaFor.palette.accent, viaForSkin.palette.accent);
      expect(viaFor.skewDegrees, viaForSkin.skewDegrees);
      expect(viaFor.motion.tabTransition, viaForSkin.motion.tabTransition);
      expect(viaFor.kit.id, viaForSkin.kit.id);
    });

    test('motion restraint is a difference between layouts, not a shared value', () {
      expect(LayoutKind.solid.kit.motion.tabTransition.inMilliseconds,
          lessThan(LayoutKind.persona.kit.motion.tabTransition.inMilliseconds));
    });
  });
}
