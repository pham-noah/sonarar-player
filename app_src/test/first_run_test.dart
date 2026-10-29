library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/constants.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/first_run_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

const _phone = Size(1179, 2556);

const _narrow = Size(1080, 2340);

Future<AppPrefs> _pump(
  WidgetTester tester, {
  AppPrefs prefs = AppPrefs.initial,
  LayoutKind layout = LayoutKind.sonar,
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  var current = prefs;
  await tester.pumpWidget(MaterialApp(
    home: Material(
      child: StatefulBuilder(
        builder: (context, setState) => FirstRunScreen(
          skin: skinFor(SkinId.crimson),
          prefs: current,
          layoutId: layout,
          onPrefs: (next) => setState(() => current = next),
          onDone: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return current;
}

void main() {
  testWidgets('it renders at a real phone width without overflow', (tester) async {
    await _pump(tester);
    expect(find.text(kAppName), findsOneWidget);

    await tester.scrollUntilVisible(find.text('START LISTENING'), 200);
    expect(find.text('START LISTENING'), findsOneWidget);

    expect(find.text('LAYOUT'), findsOneWidget);
  });

  testWidgets('the NARROWEST phone still lays out', (tester) async {
    await _pump(tester, size: _narrow);
    expect(tester.takeException(), isNull,
        reason: 'the page overflowed at the narrowest phone width');
    for (final label in const ['SONAR', 'SOLID', 'GLASS']) {
      expect(find.text(label), findsOneWidget,
          reason: 'the $label chip is missing at 360px — a choice nobody can reach');
    }
    await tester.scrollUntilVisible(find.text('START LISTENING'), 200);
    expect(find.text('START LISTENING'), findsOneWidget);
  });

  testWidgets('a layout pick is recorded in the prefs it is handed', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    AppPrefs? seen;
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: FirstRunScreen(
          skin: skinFor(SkinId.crimson),
          prefs: AppPrefs.initial,
          layoutId: LayoutKind.sonar,
          onPrefs: (next) => seen = next,
          onDone: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GLASS'));
    await tester.pumpAndSettle();
    expect(seen?.layoutId, 'glass',
        reason: 'the layout tile did not reach the prefs — the page would appear to do nothing');
  });

  testWidgets('the song-list tiles follow the layout until he picks one',
      (tester) async {
    await _pump(tester, layout: LayoutKind.solid);
    final grid = tester.widget<Text>(find.text('GRID'));

    final list = tester.widget<Text>(find.text('LIST'));
    expect(grid.style?.color, isNot(list.style?.color),
        reason: 'neither song-list tile is marked, so the page does not say what it will do');
  });

  testWidgets('picking a song-list mode writes the pref', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    AppPrefs? seen;
    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: FirstRunScreen(
          skin: skinFor(SkinId.crimson),
          prefs: AppPrefs.initial,
          layoutId: LayoutKind.sonar,
          onPrefs: (next) => seen = next,
          onDone: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('LIST'), 200);
    await tester.ensureVisible(find.text('LIST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LIST'));
    await tester.pumpAndSettle();
    expect(seen?.libraryIsGrid, isFalse);
  });

  testWidgets('the page brings its own Material frame', (tester) async {
    tester.view.physicalSize = _narrow;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: FirstRunScreen(
        skin: skinFor(SkinId.values.first),
        prefs: AppPrefs.initial,
        layoutId: LayoutKind.sonar,
        onPrefs: (_) {},
        onDone: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'the page needs a Material ancestor it does not build — that is the first-launch crash');
    expect(find.byType(Scaffold), findsWidgets,
        reason: 'the page does not bring its own frame, so the shell has to supply one');
    expect(find.text(kAppName), findsOneWidget);

    for (final label in const ['SONAR', 'SOLID', 'GLASS']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
