library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/main.dart';

class HomeShellStateProbe {
  const HomeShellStateProbe._();

  static State<HomeShell> shellStateOf(WidgetTester tester) =>
      tester.state<State<HomeShell>>(
          find.byType(HomeShell, skipOffstage: false));

  static dynamic appStateOf(WidgetTester tester) =>
      // ignore: avoid_dynamic_calls
      (shellStateOf(tester) as dynamic).widget.state;

  static dynamic shellCall(WidgetTester tester, String member, [Object? arg]) {
    // ignore: avoid_dynamic_calls
    final dynamic d = shellStateOf(tester);
    switch (member) {
      case 'tickerRunning':
        return d.tickerRunning;
      case 'debugCurrentPanel':
        return d.debugCurrentPanel;
      case 'debugOpenPanel':
        return d.debugOpenPanel(arg);
      case 'debugWantTicker':
        return d.debugWantTicker;
      case 'setDebugWantTicker':
        return d.debugWantTicker = arg;
      case 'debugSyncTicker':
        return d.debugSyncTicker();
      case 'debugFinishLoading':
        return d.debugFinishLoading();
      case 'debugOpenPlayer':
        return d.debugOpenPlayer();
      case 'debugClosePlayer':
        return d.debugClosePlayer();
      default:
        throw ArgumentError('unknown shell member: $member');
    }
  }
}
