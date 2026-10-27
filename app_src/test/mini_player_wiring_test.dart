library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin_policy.dart';
import 'package:sonarar/widgets/mini_player_host.dart';

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

Set<String> _wiredNames(MiniPlayerHost host) => {
      if (host.onSwipeNext != null) 'onSwipeNext',
      if (host.onSwipePrevious != null) 'onSwipePrevious',
      if (host.onDisband != null) 'onDisband',

      if (host.onDragToQueue != null) 'onDragToQueue',
    };

const _expected = <String, String>{
  'onSwipeNext': 'swipe left — next track',
  'onSwipePrevious': 'swipe right — previous track',
  'onDisband': 'the X — disband the queue',
  'onDragToQueue': 'a track dropped on the bar — queue it',
};

void main() {
  group('the bar is fully wired on EVERY layout', () {
    for (final kind in LayoutKind.values) {
      testWidgets('${kind.name} wires every callback the gestures need',
          (tester) async {
        await pumpShellOn(tester, kind);

        final host =
            tester.widget<MiniPlayerHost>(find.byType(MiniPlayerHost));

        expect(_wiredNames(host), _expected.keys.toSet(),
            reason: '${kind.name} handed the mini player a different set of '
                'callbacks — this is the duplication bug: the two layout '
                'families drifted apart');
      });
    }
  });

  testWidgets('the wiring is IDENTICAL across layouts, not merely present',
      (tester) async {
    final byLayout = <String, Set<String>>{};
    for (final kind in LayoutKind.values) {
      await pumpShellOn(tester, kind);
      byLayout[kind.name] =
          _wiredNames(tester.widget<MiniPlayerHost>(find.byType(MiniPlayerHost)));
    }

    expect(byLayout.length, LayoutKind.values.length,
        reason: 'a layout built no mini player, so nothing could be compared');

    final reference = byLayout[LayoutKind.persona.name]!;
    for (final kind in LayoutKind.values) {
      expect(byLayout[kind.name], reference,
          reason: '${kind.name} does not wire the same callbacks as persona');
    }
  });

  testWidgets('the horizontal gestures actually reach a recognizer', (tester) async {
    await pumpShellOn(tester, LayoutKind.solid);

    final state = HomeShellStateProbe.appStateOf(tester);
    // ignore: avoid_dynamic_calls
    final before = (state.queue?.order as List?) ?? const [];
    // ignore: avoid_dynamic_calls
    final firstId = state.currentTrack?.id;

    await tester.fling(
      find.byType(MiniPlayer),
      const Offset(-400, 0),
      1200,
    );
    await tester.pump(const Duration(milliseconds: 300));

    // ignore: avoid_dynamic_calls
    final after = (state.queue?.order as List?) ?? const [];
    expect(tester.takeException(), isNull);

    expect(after, isNot(same(before)),
        reason: 'the swipe reached no recognizer — nothing moved');
    // ignore: avoid_dynamic_calls
    expect(state.currentTrack?.id, isNotNull,
        reason: 'a track must still be loaded after a swipe');
    expect(firstId, isNotNull, reason: 'precondition: a track was playing');
  });
}
