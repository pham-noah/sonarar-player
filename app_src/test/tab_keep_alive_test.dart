library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/home_screen.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/youtube_search_screen.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

late AppState _sharedState;

Future<void> pumpShell(WidgetTester tester, {LayoutKind kind = LayoutKind.glass}) async {
  tester.view.physicalSize = const Size(412, 900) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary([for (var i = 0; i < 40; i++) _t('t$i')]);

  for (var i = 0; i < 12; i++) {
    state.createPlaylist('PL$i');
  }
  state.updateContext(const PlayContext(
      band: ContextBand.evening,
      whereabouts: Whereabouts.home,
      sky: Sky.unknown,
      localHour: 19));
  state.setLayout(kind);
  _sharedState = state;

  await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
  await tester.pump(const Duration(milliseconds: 50));
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> switchTo(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

double _widestTranslate(WidgetTester tester) {
  var widest = 0.0;
  for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
    final d = t.transform.storage[12].abs() + t.transform.storage[13].abs();
    if (d > widest) widest = d;
  }
  return widest;
}

void main() {
  group('what is mounted, and when', () {
    testWidgets('a fresh shell builds ONLY the tab it is on', (tester) async {
      await pumpShell(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LibraryScreen, skipOffstage: false), findsNothing,
          reason: 'the Library was built before anyone asked for it');
      expect(find.text('SEARCH'), findsOneWidget,
          reason: 'the tab bar is missing — the labels are what a press finds');
    });

    testWidgets('a visited tab STAYS MOUNTED while you are elsewhere', (tester) async {
      await pumpShell(tester);

      await switchTo(tester, 'LIBRARY');
      expect(find.byType(LibraryScreen), findsOneWidget);

      await switchTo(tester, 'HOME');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LibraryScreen, skipOffstage: false), findsOneWidget,
          reason: 'leaving the Library unmounted it — the whole change is not wired');
    });

    testWidgets('a tab visited once is still never REBUILT while hidden', (tester) async {
      await pumpShell(tester);
      await switchTo(tester, 'SEARCH');
      await switchTo(tester, 'HOME');

      expect(find.byType(YoutubeSearchScreen, skipOffstage: false), findsOneWidget);
    });
  });

  group('the State survives the switch', () {
    testWidgets('the scroll position is still where you left it', (tester) async {
      await pumpShell(tester);
      await switchTo(tester, 'LIBRARY');

      final list = find.descendant(
        of: find.byType(LibraryScreen),
        matching: find.byType(Scrollable),
      );
      final scrollable = tester.state<ScrollableState>(list.first);
      await tester.fling(list.first, const Offset(0, -600), 1200);
      await tester.pumpAndSettle();

      final before = scrollable.position.pixels;
      expect(before, greaterThan(0),
          reason: 'precondition: the list did not scroll, so there is nothing to preserve');

      await switchTo(tester, 'HOME');
      await switchTo(tester, 'LIBRARY');

      final scrollableAfter = tester.state<ScrollableState>(list.first);
      expect(identical(scrollable, scrollableAfter), isTrue,
          reason: 'the Library came back as a NEW element — its State (and everything in it) was '
              'thrown away, which is the whole cost this change removes');
      expect(scrollableAfter.position.pixels, before,
          reason: 'the library came back at the top — the scroll offset was thrown away');
    });
  });

  group('and it still ARRIVES', () {
    testWidgets('the arrival replays on the way back', (tester) async {
      await pumpShell(tester);
      await switchTo(tester, 'LIBRARY');
      await switchTo(tester, 'HOME');
      final atRest = _widestTranslate(tester);

      await tester.tap(find.text('LIBRARY'));
      await tester.pump();

      expect(_widestTranslate(tester), greaterThan(atRest + 1),
          reason: 'a kept-alive tab came back with no entrance — the arrival only played when a '
              'fresh view happened to be built, and no view is built now');
    });

    testWidgets('an UNRELATED rebuild does not replay it', (tester) async {
      await pumpShell(tester);
      await switchTo(tester, 'LIBRARY');
      final atRest = _widestTranslate(tester);

      await tester.pumpWidget(
          MaterialApp(home: HomeShell(state: _sharedState)));
      await tester.pumpAndSettle();

      expect(_widestTranslate(tester), lessThan(atRest + 1),
          reason: 'the arrival twitched on a plain rebuild — an entrance is an entrance, not a '
              'frame-rate');
    });
  });
}
