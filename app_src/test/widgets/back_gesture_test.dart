@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/screens/player_screen.dart';

import '../shell_probe.dart';

final List<String> calls = [];

Future<AppState> _boot(WidgetTester tester) async {
  calls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    calls.add(call.method);
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final state = AppState();
  await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
  await tester.pump(const Duration(milliseconds: 50));
  HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  return state;
}

void main() {
  group('the back gesture', () {
    testWidgets('does not close the app while something is open to undo', (tester) async {
      await _boot(tester);

      HomeShellStateProbe.shellCall(tester, 'debugOpenPanel', PlayerPanel.queue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'opening the panel threw');

      final before = _panelOf(tester);
      expect(before, isNot(PlayerPanel.none),
          reason: 'precondition: the panel did not open, so this proves nothing');

      calls.clear();
      _pressBack(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, isNot(contains('SystemNavigator.pop')),
          reason: 'the back press asked the platform to close the app while a panel was open — the handler read '
              'the state it had just cleared instead of deciding the action first');
      expect(_panelOf(tester), PlayerPanel.none,
          reason: 'the back press did not close the open panel either');
    });

    testWidgets('does not close the app while there is tab history', (tester) async {
      await _boot(tester);

      await tester.tap(find.text('SEARCH'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('LIBRARY'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));

      _pressBack(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HomeShell), findsOneWidget,
          reason: 'the first back press closed the app instead of returning to the previous tab');
    });
  });
}

PlayerPanel _panelOf(WidgetTester tester) =>
    HomeShellStateProbe.shellCall(tester, 'debugCurrentPanel') as PlayerPanel;

void _pressBack(WidgetTester tester) {
  // ignore: discarded_futures
  tester.binding.handlePopRoute();
}
