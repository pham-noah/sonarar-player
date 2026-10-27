@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/tab_motif.dart';

Widget _host(TabArrival arrival, {double drift = 1.0}) => Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 800,
        child: TabArrivalView(
          arrival: arrival,
          drift: drift,
          child: const ColoredBox(color: Color(0xFF0000FF)),
        ),
      ),
    );

double _residual(WidgetTester tester) {
  var worst = 0.0;
  for (final t in tester.widgetList<Transform>(find.byType(Transform))) {
    final v = t.transform.getTranslation();
    worst = [worst, v.x.abs(), v.y.abs()].reduce((a, b) => a > b ? a : b);
  }
  return worst;
}

void main() {
  for (final arrival in TabArrival.values) {
    for (final drift in <double>[1.0, 0.55]) {
      testWidgets('${arrival.name} at drift $drift settles to EXACTLY zero',
          (tester) async {
        await tester.pumpWidget(_host(arrival, drift: drift));

        await tester.pump(Motion.tabBackdrop + const Duration(milliseconds: 32));
        await tester.pump();

        expect(_residual(tester), lessThan(0.01),
            reason: 'the arrival rests displaced, which is the edge he sees');
      });
    }
  }

  testWidgets('and the travel is real before it settles', (tester) async {
    await tester.pumpWidget(_host(TabArrival.zigzagSlant));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_residual(tester), greaterThan(20.0),
        reason: 'the arrival does not move at all, so there is no entrance left');
  });
}
