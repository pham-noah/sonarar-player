@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/theme/skin.dart';

class _Counter {
  int n = 0;
  void call() => n++;
}

void main() {
  testWidgets('a ListenableBuilder on the state rebuilds when it changes',
      (tester) async {
    final state = AppState();
    var builds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            builds++;
            return const Text('shell', textDirection: TextDirection.ltr);
          },
        ),
      ),
    );
    expect(builds, 1);

    state.setSleeping(true);
    await tester.pump();
    expect(builds, greaterThan(1),
        reason: 'the shell would not rebuild on a state change — nothing would update');
  });

  testWidgets('the skin notifier fires without the state notifier doing the work',
      (tester) async {
    final state = AppState();
    final skinBuilds = _Counter();
    final stateBuilds = _Counter();
    state.skinListenable.addListener(skinBuilds.call);
    state.addListener(stateBuilds.call);

    state.chooseSkinManually(SkinId.crimson);
    expect(skinBuilds.n, 1, reason: 'the theme would not change');
    expect(stateBuilds.n, greaterThanOrEqualTo(1));
  });

  group('the shell load chain does not throw', () {
    testWidgets('AppState survives context, band and sleep changes with an empty library',
        (tester) async {
      final state = AppState();

      state.setSleeping(true);
      state.setSleeping(false);
      state.setDerivedPlaylists(const []);
      expect(state.queue, isNull);
      expect(state.dynamicMix(), isNull,
          reason: 'a mix was produced with no library and no context');
    });
  });
}
