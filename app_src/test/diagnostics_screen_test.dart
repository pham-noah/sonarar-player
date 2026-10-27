@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/diag_log.dart';
import 'package:sonarar/screens/diagnostics_screen.dart';
import 'package:sonarar/theme/skin.dart';

Widget _wrap(DiagLog log) => MaterialApp(
      home: Scaffold(body: DiagnosticsPanel(skin: kSkinCrimson, log: log)),
    );

void main() {
  testWidgets('an empty log says so rather than showing a blank panel',
      (tester) async {
    await tester.pumpWidget(_wrap(DiagLog()));
    await tester.pump();
    expect(find.textContaining('Nothing has gone wrong'), findsOneWidget);
  });

  testWidgets('PROBLEMS is the default reading and shows only the failures',
      (tester) async {
    final log = DiagLog()
      ..add('[Sonarar][LOAD] #1 first items=24')
      ..add('[Sonarar][LOAD] #2 FAILED: Connection aborted');
    await tester.pumpWidget(_wrap(log));
    await tester.pump();

    expect(find.textContaining('Connection aborted'), findsOneWidget);
    expect(find.textContaining('items=24'), findsNothing);
  });

  testWidgets('ALL shows every line, including the healthy ones', (tester) async {
    final log = DiagLog()
      ..add('[Sonarar][LOAD] #1 first items=24')
      ..add('[Sonarar][LOAD] #2 FAILED: Connection aborted');
    await tester.pumpWidget(_wrap(log));
    await tester.pump();

    await tester.tap(find.textContaining('ALL'));
    await tester.pump();

    expect(find.textContaining('items=24'), findsOneWidget);
    expect(find.textContaining('Connection aborted'), findsOneWidget);
  });

  testWidgets('a line printed after opening still appears', (tester) async {
    final log = DiagLog();
    await tester.pumpWidget(_wrap(log));
    await tester.pump();
    expect(find.textContaining('Nothing has gone wrong'), findsOneWidget);

    log.add('[Sonarar][SHORTQUEUE] order=1');
    await tester.pump();

    expect(find.textContaining('SHORTQUEUE'), findsOneWidget);
  });

  testWidgets('CLEAR empties it', (tester) async {
    final log = DiagLog()..add('[Sonarar][LOAD] #1 first items=24');
    await tester.pumpWidget(_wrap(log));
    await tester.pump();

    await tester.tap(find.text('CLEAR'));
    await tester.pump();

    expect(log.isEmpty, isTrue);
    expect(find.textContaining('Nothing has gone wrong'), findsOneWidget);
  });
}
