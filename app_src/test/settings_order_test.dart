library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin_policy.dart';

const _wanted = <String>[
  'LOOK',
  'BEHAVIOUR',
  'IF SOMETHING IS WRONG',
];

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

void main() {
  testWidgets('the settings sections run in the order he set', (tester) async {
    tester.view.physicalSize = const Size(420, 4200) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.attachLibrary([for (var i = 0; i < 6; i++) _t('t$i')]);
    state.updateContext(const PlayContext(
        band: ContextBand.evening, sky: Sky.unknown, localHour: 19));

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: SettingsScreen(
          onOpenPersonalize: () {},
          state: state,
          prefs: AppPrefs.initial,
          onPrefsChanged: (_) {},
          onOpenDiagnostics: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final found = <String, double>{};
    for (final label in _wanted) {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) continue;
      found[label] = tester.getTopLeft(finder.first).dy;
    }

    final order = found.keys.toList()
      ..sort((a, b) => found[a]!.compareTo(found[b]!));
    // ignore: avoid_print
    print('settings section order: $order');

    expect(found.keys.toSet(), _wanted.toSet(),
        reason: 'a settings section is missing from the screen entirely');

    expect(order, _wanted,
        reason: 'the settings sections are out of order — if that was deliberate, update `_wanted`');
  });

  testWidgets('the settings screen PAINTS in the layout\'s colours, not the skin\'s',
      (tester) async {
    Future<Color> pageColourFor(LayoutKind kind) async {
      tester.view.physicalSize = const Size(420, 900) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 6; i++) _t('t$i')]);
      state.setLayout(kind);

      await tester.pumpWidget(MaterialApp(
        home: Material(

          child: RepaintBoundary(
            child: SettingsScreen(state: state, prefs: AppPrefs.initial),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final image = await tester.runAsync(() async {
        final boundary = tester
            .renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
        final img = await boundary.toImage();
        final w = img.width;
        final h = img.height;
        final bytes = await img.toByteData(format: ui.ImageByteFormat.rawRgba);

        final idx = ((h - 60) * w + 10) * 4;
        final b = bytes!;
        return Color.fromARGB(
            b.getUint8(idx + 3), b.getUint8(idx), b.getUint8(idx + 1), b.getUint8(idx + 2));
      });
      return image!;
    }

    final persona = await pageColourFor(LayoutKind.sonar);
    final solid = await pageColourFor(LayoutKind.solid);
    // ignore: avoid_print
    print('settings page colour: persona=$persona solid=$solid');

    expect(solid, isNot(persona),
        reason: 'Settings painted the same under Solid as under Persona — it is reading the raw skin');
  });
}
