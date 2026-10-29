library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/settings_screen.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

Widget _page(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: SafeArea(

          top: true,
          bottom: false,
          child: Scaffold(body: child),
        ),
      ),
    );

const _maxFirstSectionTop = 20.0;

void main() {
  Future<double> firstSectionTop(WidgetTester tester, SettingsSection section,
      {bool showTitle = false}) async {
    tester.view.physicalSize = const Size(420, 2400) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState()..attachLibrary([_t('a')]);
    await tester.pumpWidget(_page(SettingsScreen(
      state: state,
      section: section,
      showTitle: showTitle,
      onOpenPersonalize: () {},

      prefs: const AppPrefs(),
      onPrefsChanged: (_) {},
    )));

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final labels = <String>[
      'LOOK',
      'BEHAVIOUR',
      'IF SOMETHING IS WRONG',
    ];
    for (final label in labels) {
      final found = find.text(label);
      if (found.evaluate().isNotEmpty) {
        final top =
            tester.getTopLeft(found.first).dy / tester.view.devicePixelRatio;
        // ignore: avoid_print
        print('$label section top: ${top.toStringAsFixed(1)} logical px');
        return top;
      }
    }
    fail('no settings section rendered at all');
  }

  group('the pushed page opens with NO headroom', () {
    testWidgets('B E H A V I O U R', (tester) async {
      final top = await firstSectionTop(tester, SettingsSection.behaviour);
      expect(top, lessThanOrEqualTo(_maxFirstSectionTop),
          reason: 'the behaviour page opens with ${top.toStringAsFixed(1)}px of '
              'empty space above the first section — that is the headroom. '
              'A section spacer left outside its gate shows up here');
    });

    testWidgets('P E R S O N A L I Z E', (tester) async {
      final top = await firstSectionTop(tester, SettingsSection.customization);
      expect(top, lessThanOrEqualTo(_maxFirstSectionTop),
          reason: 'the personalize page opens with ${top.toStringAsFixed(1)}px '
              'of empty space above the first section');
    });

    testWidgets('A L L', (tester) async {
      final top = await firstSectionTop(tester, SettingsSection.all);
      expect(top, lessThanOrEqualTo(_maxFirstSectionTop),
          reason: 'the single-page settings opens with ${top.toStringAsFixed(1)}px '
              'of empty space above the first section');
    });
  });

  testWidgets('the title variant is not silently made headroom', (tester) async {
    final top = await firstSectionTop(tester, SettingsSection.behaviour,
        showTitle: true);
    expect(top, lessThan(_maxFirstSectionTop + 40),
        reason: 'the titled variant carries far more than a title and a gap');
  });
}
