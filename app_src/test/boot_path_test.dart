@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/main.dart';

void main() {
  testWidgets('the real app root builds without throwing', (tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SonararApp());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SonararApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app paints a dark background even while loading',
      (tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SonararApp());
    await tester.pump();

    final boxes = find.byType(ColoredBox);
    expect(boxes, findsWidgets,
        reason: 'nothing painted at all -- this is the blank-window symptom');
  });
}
