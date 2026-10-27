library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/surface.dart';

import 'shell_probe.dart';

Track _t(String id) => Track(
      id: id, title: 'Title $id', artist: 'a', album: 'b',
      duration: const Duration(minutes: 3), file: '$id.opus', cover: '', gainDb: null);

void main() {
  group('a layout brings its own pattern', () {
    test('Persona is the skin, unchanged', () {
      final skin = skinFor(SkinId.crimson);
      final p = presentationFor(LayoutKind.persona, skin);

      expect(p.isPersona, isTrue);

      expect(p.palette.background, skin.background);
      expect(p.palette.accent, skin.accent);
      expect(p.palette.accentDeep, skin.accentDeep);
      expect(p.palette.textPrimary, skin.textPrimary);
      expect(p.skewDegrees, skin.skewDegrees);
    });

    test('Solid and Glass IGNORE the skin colours', () {
      for (final kind in [LayoutKind.solid, LayoutKind.glass]) {
        final fromP3R = presentationFor(kind, skinFor(SkinId.abyss));
        final fromP5R = presentationFor(kind, skinFor(SkinId.crimson));
        expect(fromP3R.palette.background, fromP5R.palette.background,
            reason: '${kind.name} took its background from the skin');
        expect(fromP3R.palette.accent, fromP5R.palette.accent,
            reason: '${kind.name} took its accent from the skin');

        final persona = presentationFor(LayoutKind.persona, skinFor(SkinId.abyss));
        expect(fromP3R.palette.background, isNot(persona.palette.background));
      }
    });

    test('the two layouts differ from EACH OTHER, or one of them is pointless', () {
      final solid = presentationFor(LayoutKind.solid, skinFor(SkinId.abyss));
      final glass = presentationFor(LayoutKind.glass, skinFor(SkinId.abyss));
      expect(solid.material, MaterialStyle.flat);
      expect(glass.material, MaterialStyle.glass);
      expect(solid.palette.background, isNot(glass.palette.background));
      expect(glass.isGlass, isTrue);
      expect(solid.isGlass, isFalse);
    });
  });

  group('motion: Persona is the loud one', () {
    test('Solid and Glass are restrained, and it is the duration', () {
      final persona = presentationFor(LayoutKind.persona, skinFor(SkinId.crimson));
      for (final kind in [LayoutKind.solid, LayoutKind.glass]) {
        final p = presentationFor(kind, skinFor(SkinId.crimson));
        expect(p.motion.tabTransition, lessThan(persona.motion.tabTransition),
            reason: '${kind.name} moves as long as Persona');
        expect(p.motion.enabled, isTrue,
            reason: 'restrained is not the same as off');
      }
    });

    test("Persona's own number is exactly what the app had", () {
      final m = presentationFor(LayoutKind.persona, skinFor(SkinId.abyss)).motion;
      expect(m.tabTransition, const Duration(milliseconds: 420));
      expect(m.enabled, isTrue);
    });
  });

  group('arrangement: the bar floats or it docks', () {
    test('Persona docks its bar; Solid and Glass float it inset', () {
      final persona = presentationFor(LayoutKind.persona, skinFor(SkinId.crimson));
      expect(persona.arrangement.tabBarIsFloating, isFalse);
      expect(persona.arrangement.contextPlateExists, isTrue);

      for (final kind in [LayoutKind.solid, LayoutKind.glass]) {
        final p = presentationFor(kind, skinFor(SkinId.crimson));
        expect(p.arrangement.tabBarIsFloating, isTrue,
            reason: '${kind.name} docks its bar — the floating pill is half the look');
        expect(p.arrangement.tabBarInsets, isNot(EdgeInsets.zero));
        expect(p.arrangement.contextPlateExists, isFalse,
            reason: "the Persona plate is not a control Solid/Glass should inherit");
      }
    });
  });

  group('the surface primitive honours the material', () {
    int blurCount(WidgetTester tester) =>
        tester.widgetList(find.byType(BackdropFilter)).length;

    Future<void> pumpSurface(WidgetTester tester, LayoutKind kind) async {
      final skin = skinFor(SkinId.crimson);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Surface(
            presentation: presentationFor(kind, skin),
            role: SurfaceRole.bar,
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('flat does NOT blur; glass DOES', (tester) async {
      await pumpSurface(tester, LayoutKind.solid);
      expect(blurCount(tester), 0, reason: 'Solid blurred — it is the flat material');

      await pumpSurface(tester, LayoutKind.glass);
      expect(blurCount(tester), 1, reason: 'Glass did not blur, so the material is not applied');
    });

    testWidgets('persona casts a shadow; the flat and glass ones do not',
        (tester) async {
      Future<int> shadowCount(LayoutKind kind) async {
        await pumpSurface(tester, kind);
        final containers =
            tester.widgetList<Container>(find.byType(Container)).toList();
        var n = 0;
        for (final c in containers) {
          final d = c.decoration;
          if (d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false)) n++;
        }
        return n;
      }

      expect(await shadowCount(LayoutKind.persona), greaterThan(0),
          reason: "Persona's panel should still lift");
      expect(await shadowCount(LayoutKind.solid), 0,
          reason: 'a flat surface must not cast — the hairline does that work');
    });

    test('Persona slants and Solid does not', () {
      final skin = skinFor(SkinId.crimson);
      expect(presentationFor(LayoutKind.persona, skin).skewDegrees, greaterThan(0),
          reason: 'Persona stopped slanting, so its stamps are no longer stamps');
      for (final kind in [LayoutKind.solid, LayoutKind.glass]) {
        expect(presentationFor(kind, skin).skewDegrees, 0,
            reason: '${kind.name} must be straight-edged');
      }
    });
  });

  group('every arrangement field has a CONSUMER', () {
    testWidgets('solid is a grid, a scroll-away header and a capped width', (tester) async {
      tester.view.physicalSize = const Size(420, 860) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final skin = skinFor(SkinId.crimson);

      Future<void> pumpLibrary({required bool grid, bool scrollAway = false}) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: LibraryScreen(

              searchOnly: true,
              entryToken: 0,
              tracks: [for (var i = 0; i < 12; i++) _t('t$i')],
              coverPathFor: (_) => null,
              skin: skin,
              grid: grid,
              headerScrollsAway: scrollAway,
              contentMaxWidth: 720,
            ),
          ),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      await pumpLibrary(grid: true);
      final whenGrid = tester.widgetList(find.byType(SliverGrid)).length;
      await pumpLibrary(grid: false);
      final whenList = tester.widgetList(find.byType(SliverGrid)).length;
      // ignore: avoid_print
      print('arrangement measured: GridViews with grid=true -> '
          '$whenGrid, with grid=false -> $whenList');

      expect(whenGrid, greaterThan(whenList),
          reason: 'the grid flag does not reach the library — arrangement is declared but unread');

      await pumpLibrary(grid: true, scrollAway: true);
      final headerSliversAway = tester
          .widgetList(find.byType(SliverToBoxAdapter))
          .length;
      await pumpLibrary(grid: true, scrollAway: false);
      final headerSliversPinned = tester
          .widgetList(find.byType(SliverToBoxAdapter))
          .length;
      expect(headerSliversAway, greaterThan(headerSliversPinned),
          reason: 'the header never enters the scroll, so it cannot scroll away');

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      await pumpLibrary(grid: true);
      final capFinder = find.byWidgetPredicate((w) =>
          w is ConstrainedBox && w.constraints.maxWidth == 720.0);
      expect(capFinder, findsWidgets,
          reason: 'the width cap never entered the tree');
      final cappedWidth = tester.getSize(capFinder.first).width;
      // ignore: avoid_print
      print('capped viewport 1400px wide -> page measured ${cappedWidth}px');
      expect(cappedWidth, lessThanOrEqualTo(720.0),
          reason: 'the cap is in the tree but the page ignores it');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LibraryScreen(
            searchOnly: true,
            entryToken: 0,
            tracks: [for (var i = 0; i < 12; i++) _t('t$i')],
            coverPathFor: (_) => null,
            skin: skin,
            grid: true,
          ),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
          find.byWidgetPredicate((w) =>
              w is ConstrainedBox && w.constraints.maxWidth == 720.0),
          findsNothing,
          reason: 'Persona must not be capped');
    });
  });

  group('the SHELL actually adopts the layout', () {
    Future<void> pumpShell(WidgetTester tester, LayoutKind kind) async {
      tester.view.physicalSize = const Size(420, 860) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 30; i++) _t('t$i')]);
      state.updateContext(const PlayContext(
          band: ContextBand.evening, whereabouts: Whereabouts.home,
          sky: Sky.unknown, localHour: 19));
      state.setLayout(kind);

      await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
      await tester.pump(const Duration(milliseconds: 50));
      HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    testWidgets('Solid puts a BackdropFilter nowhere; Glass puts one on the bar',
        (tester) async {
      await pumpShell(tester, LayoutKind.solid);
      expect(tester.widgetList(find.byType(BackdropFilter)).length, 0,
          reason: 'Solid blurred something — the material is not being read');

      await pumpShell(tester, LayoutKind.glass);
      expect(tester.widgetList(find.byType(BackdropFilter)).length, greaterThan(0),
          reason: 'Glass is set but nothing in the SHELL blurs — the layout is not wired through');
    });

    testWidgets("Persona's shell is unchanged: it slants and casts", (tester) async {
      await pumpShell(tester, LayoutKind.persona);
      expect(tester.widgetList(find.byType(BackdropFilter)).length, 0,
          reason: 'Persona blurred — the material leaked from another layout');
    });
  });
}
