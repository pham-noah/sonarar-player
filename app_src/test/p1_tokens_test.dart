library;

// The P1 token decisions, each one a rule the audit wrote down in §2.4–§2.6
// plus the two state-language fixes from the review. Each test names the rule
// it holds, so a later change that undoes it fails here rather than in a render
// nobody looked at.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/layout_kit.dart';
import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/tokens.dart';

void main() {
  group('elevation (§2.5): a shadow cannot lift a plate on a near-black page', () {
    test('e2 and e3 carry the 1px rim on dark', () {
      for (final level in <List<BoxShadow> Function({required bool light})>[
        Elevation.e2,
        Elevation.e3,
      ]) {
        final dark = level(light: false);
        expect(
          dark.any((s) => s.color == const Color(0x1AFFFFFF) && s.offset.dy == -1),
          isTrue,
          reason: 'no rim light: on a #000 page the drop shadow measures ~1:1, '
              'so without the rim the plate has no top edge at all',
        );
        expect(dark.length, greaterThan(1),
            reason: 'the rim is not a substitute for the drop shadow');
      }
    });

    test('light skins get the drop shadow and no rim', () {
      final light = Elevation.e2(light: true);
      expect(light.where((s) => s.color == const Color(0x1AFFFFFF)), isEmpty,
          reason: 'a white rim on a pale page is invisible at best, a smudge at worst');
      expect(light, isNotEmpty);
    });

    test('e0 is flat and e1 is flat on dark', () {
      expect(Elevation.e0, isEmpty);
      expect(Elevation.e1(light: false), isEmpty,
          reason: 'e1 is a borderStrong edge on dark, not a shadow');
      expect(Elevation.e1(light: true), isNotEmpty,
          reason: 'on a light page e1 is a 1px soft shadow under the edge');
    });
  });

  group('radii (§2.4): three roles, and a default that is one of them', () {
    test('r-sm 4, r-md 12, r-lg 24, pill', () {
      expect(MaterialRadius.sm, 4);
      expect(MaterialRadius.md, 12);
      expect(MaterialRadius.lg, 24);
      expect(MaterialRadius.defaultRadius, MaterialRadius.md,
          reason: 'a theme without radii used to fall back to a bare 4.0');
    });
  });

  group('edge() is decoration and cannot be floored (§2.1)', () {
    test('secondary() clamps, edge() does not', () {
      for (final skin in kAllSkins) {
        final asked = 0.12;
        expect(skin.secondary(asked).a, greaterThan(asked),
            reason: '${skin.id.name}: secondary() stopped clamping to its '
                '4.5:1 text floor');
        expect(skin.edge(asked).a, closeTo(asked, 0.001),
            reason: '${skin.id.name}: edge() was clamped to the text floor, so '
                'every hairline renders near-solid on the light skins again');
      }
    });

    test('a hairline stays under the floor it is exempt from', () {
      const skin = kSkinMinimal;
      expect(skin.edge(Tone.edge).a, lessThan(skin.mutedFloor),
          reason: 'Minimal is the theme where a 0.28 divider became a 0.90 border');
    });
  });

  group('a switch that cannot be operated does not look operable', () {
    test('disabled resolves to a dimmer track and knob than either state', () {
      final ink = SwitchInk.ofSkin(kSkinAbyss);
      final off = ink.track.resolve(<WidgetState>{});
      final on = ink.track.resolve(<WidgetState>{WidgetState.selected});
      final offDisabled = ink.track.resolve(<WidgetState>{WidgetState.disabled});

      expect(offDisabled, isNot(off),
          reason: 'a gated row drew its switch at full contrast — Material only '
              'dims a disabled switch on Cupertino');
      expect(offDisabled.a, lessThan(off.a));
      expect(offDisabled, isNot(on));

      final knobOff = ink.thumb.resolve(<WidgetState>{});
      final knobOffDisabled = ink.thumb.resolve(<WidgetState>{WidgetState.disabled});
      expect(knobOffDisabled.a, lessThan(knobOff.a),
          reason: 'the track dimmed but the knob did not');
    });
  });

  group('motion is four durations and three curves (§2.6)', () {
    test('every duration is one of the four, or the stagger step', () {
      final named = <String, Duration>{
        'press': Motion.press,
        'release': Motion.release,
        'base': Motion.base,
        'screen': Motion.screen,
      };
      for (final entry in <String, Duration>{
        'pressIn': Motion.pressIn,
        'pressOut': Motion.pressOut,
        'morph': Motion.morph,
        'artCrossFade': Motion.artCrossFade,
        'panel': Motion.panel,
        'tabArrival': Motion.tabArrival,
        'stagger': Motion.stagger,
      }.entries) {
        expect(named.values, contains(entry.value),
            reason: '${entry.key} is not one of the four durations');
      }
      expect(named['press'], const Duration(milliseconds: 90));
      expect(named['release'], const Duration(milliseconds: 160));
      expect(named['base'], const Duration(milliseconds: 200));
      expect(named['screen'], const Duration(milliseconds: 320));
    });

    test('the backdrop is the screen duration times its factor, not a fifth one',
        () {
      // Deliberately not one of the four: the layer behind the content drifts
      // on past the content's own landing (1.65 × screen on Persona), which is
      // the whole point of the layering. It must still derive from a token.
      expect(Motion.backdropFactor, 1.65);
      expect(Motion.tabBackdrop.inMicroseconds,
          (Motion.screen.inMicroseconds * Motion.backdropFactor).round());
    });

    test('the stagger never outruns the screen change, and is capped', () {
      expect(Motion.staggerStep * Motion.staggerCap,
          lessThanOrEqualTo(Motion.screen),
          reason: 'a stagger longer than the screen change leaves rows still '
              'arriving after the tab has landed');
      expect(Motion.staggerStep, const Duration(milliseconds: 40));
      expect(Motion.staggerCap, 5);
    });

    test('no curve overshoots', () {
      expect(MotionCurve.arrival, isNot(Curves.easeOutBack),
          reason: 'easeOutBack on a 46px hero reads as a layout bug');
      expect(MotionCurve.standard, Curves.easeOutCubic);
      expect(MotionCurve.cross, Curves.easeInOut);
    });
  });

  group('an unreadable folder is not an empty one', () {
    Future<void> pump(
      WidgetTester tester, {
      bool accessDenied = false,
      int missing = 0,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: LibraryScreen(
            view: LibraryScreenView(
              tracks: const [],
              coverPathFor: (_) => null,
              skin: kSkinCrimson,
              libraryRoot: '/music',
              accessDenied: accessDenied,
              missingCount: missing,
              onChooseFolder: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the two states are different pages', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('library-empty')), findsOneWidget);
      expect(find.byKey(const Key('library-unreadable')), findsNothing);
      expect(find.text('No music yet'), findsOneWidget);

      await pump(tester, accessDenied: true);
      expect(find.byKey(const Key('library-unreadable')), findsOneWidget);
      expect(find.byKey(const Key('library-empty')), findsNothing);
      expect(find.text('No music yet'), findsNothing,
          reason: 'a folder the OS refused to open is not empty, and telling '
              'the user there is no music yet sends them looking for the wrong fix');
      expect(find.text("Can't read this folder"), findsOneWidget);
    });

    testWidgets('a manifest with missing songs gets its own heading',
        (tester) async {
      await pump(tester, missing: 3);
      expect(find.byKey(const Key('library-unreadable')), findsOneWidget);
      expect(find.text('Your music has moved'), findsOneWidget);
      expect(find.text("Can't read this folder"), findsNothing,
          reason: 'missing files are readable folder, moved songs');
    });
  });
}
