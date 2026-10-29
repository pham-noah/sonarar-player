library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/constants.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';

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

Future<void> pumpShellOn(WidgetTester tester, LayoutKind kind) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final state = AppState();
  state.attachLibrary([for (var i = 0; i < 12; i++) _t('t$i')]);
  state.updateContext(const PlayContext(
      band: ContextBand.evening,
      whereabouts: Whereabouts.home,
      sky: Sky.unknown,
      localHour: 19));
  state.setLayout(kind);
  state.playTrack(state.library.first);

  await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
  await tester.pump(const Duration(milliseconds: 50));
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Duration _transitionFor(WidgetTester tester) {
  final motion = HomeShellStateProbe.appStateOf(tester)?.motion;
  // ignore: avoid_dynamic_calls
  return (motion?.tabTransition as Duration?) ?? const Duration(milliseconds: 420);
}

Future<void> pumpTransition(WidgetTester tester, {int steps = 6}) async {
  final total = _transitionFor(tester);
  for (var i = 0; i < steps; i++) {
    await tester.pump(Duration(milliseconds: total.inMilliseconds ~/ steps));
  }
}

Finder _coverHeroes(String trackId) => find.byWidgetPredicate(
      (w) => w is Hero && w.tag == kCoverHeroTag(trackId),
    );

void main() {
  group('the cover grows out of the bar', () {
    for (final kind in LayoutKind.values) {
      testWidgets('${kind.name}: the bar is the flight source, and stays one',
          (tester) async {
        await pumpShellOn(tester, kind);

        final trackId = HomeShellStateProbe.appStateOf(tester)?.currentTrack?.id;
        // ignore: avoid_dynamic_calls
        final id = trackId as String?;
        expect(id, isNotNull, reason: 'precondition: a track is playing');
        final trackId2 = id!;

        expect(_coverHeroes(trackId2), findsOneWidget,
            reason: 'the mini player\'s cover carries no Hero, so it cannot '
                'grow into the player — it would just vanish');

        HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        expect(_coverHeroes(trackId2), findsNWidgets(2),
            reason: 'the two covers are not both in the tree at the same time, '
                'so there is no flight to run — the bar was unmounted before '
                'the route started animating');
      });
    }
  });

  testWidgets('the bar survives the whole flight and comes back', (tester) async {
    await pumpShellOn(tester, LayoutKind.sonar);

    HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 420 ~/ 5));
      expect(find.byType(MiniPlayer), findsOneWidget,
          reason: 'the bar was unmounted mid-flight at step $i, so the cover '
              'could not grow out of it');
    }

    await pumpTransition(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MiniPlayer), findsNothing,
        reason: 'the settled route should have released the bar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing puts the bar back before the return flight', (tester) async {
    await pumpShellOn(tester, LayoutKind.solid);

    final navigator =
        Navigator.of(tester.element(find.byType(HomeShell)), rootNavigator: true);

    HomeShellStateProbe.shellCall(tester, 'debugOpenPlayer');
    await pumpTransition(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MiniPlayer), findsNothing,
        reason: 'precondition: the settled player route has released the bar');

    navigator.pop();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byType(MiniPlayer), findsOneWidget,
        reason: 'the bar was not restored for the return flight, so the cover '
            'has nowhere to land');
  });
}
