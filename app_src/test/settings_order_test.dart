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

/// Tabs run in this order, and each tab's sections run in this order.
const _wanted = <String, List<String>>{
  'LOOK': ['LOOK'],
  'PLAYBACK': ['PLAYBACK', 'CONTEXT', 'LISTENING MEMORY'],
  'LIBRARY': ['LIBRARY'],
  'SYSTEM': ['INTERFACE', 'IF SOMETHING IS WRONG'],
};

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

    // The tabs run left to right in the order a person reads them.
    // Tabs are addressed by key: PLAYBACK is both a tab and a section band, so
    // matching on the word alone finds two widgets.
    final keys = {
      'LOOK': 'settings-tab-look',
      'PLAYBACK': 'settings-tab-playback',
      'LIBRARY': 'settings-tab-library',
      'SYSTEM': 'settings-tab-system',
    };
    for (final tab in _wanted.keys) {
      expect(find.byKey(Key(keys[tab]!)), findsOneWidget,
          reason: 'the $tab tab is missing from Settings');
    }
    final order = _wanted.keys.toList();
    for (var i = 1; i < order.length; i++) {
      expect(
        tester.getTopLeft(find.byKey(Key(keys[order[i]]!))).dx,
        greaterThan(
            tester.getTopLeft(find.byKey(Key(keys[order[i - 1]]!))).dx),
        reason: 'the settings tabs are out of order',
      );
    }

    // Inside a tab, its sections run down the page in order.
    for (final entry in _wanted.entries) {
      await tester.tap(find.byKey(Key(keys[entry.key]!)));
      await tester.pumpAndSettle();

      final found = <String, double>{};
      for (final label in entry.value) {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) continue;
        found[label] = tester.getTopLeft(finder.first).dy;
      }

      expect(found.keys.toSet(), entry.value.toSet(),
          reason: 'a section is missing from the ${entry.key} tab');

      final seen = found.keys.toList()
        ..sort((a, b) => found[a]!.compareTo(found[b]!));
      expect(seen, entry.value,
          reason: 'the ${entry.key} sections are out of order');
    }
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
