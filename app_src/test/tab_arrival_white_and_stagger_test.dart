@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/tab_motif.dart';
import 'package:sonarar/widgets/stagger_in.dart';

Widget _arrival(TabArrival arrival, {double drift = 1.0, Duration? duration}) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: TabArrivalView(
          key: const ValueKey('a'),
          arrival: arrival,
          drift: drift,
          duration: duration,
          child: const SizedBox(width: 400, height: 400),
        ),
      ),
    );

List<double> _scales(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .map((t) => t.transform.getMaxScaleOnAxis())
    .toList();

double _maxScale(WidgetTester tester) =>
    _scales(tester).reduce((a, b) => a > b ? a : b);
double _minScale(WidgetTester tester) =>
    _scales(tester).reduce((a, b) => a < b ? a : b);

void main() {
  group('the page is never uncovered (the white he saw)', () {
    testWidgets('the scale NEVER goes below 1, at any point in any arrival',
        (tester) async {
      for (final arrival in TabArrival.values) {
        await tester.pumpWidget(_arrival(arrival));
        var minScale = double.infinity;
        for (var ms = 0; ms <= Motion.tabArrival.inMilliseconds; ms += 20) {
          await tester.pump(Duration(milliseconds: 20));
          final s = _minScale(tester);
          if (s < minScale) minScale = s;
        }
        expect(minScale, greaterThanOrEqualTo(1.0),
            reason: '${arrival.name} scales below 1, so the page shows through');
      }
    });

    testWidgets('it comes in LARGER and settles to exactly 1', (tester) async {
      await tester.pumpWidget(_arrival(TabArrival.zigzagSlant));
      expect(_maxScale(tester), greaterThan(1.05),
          reason: 'it should start visibly larger for the punch');
      await tester.pump(Motion.tabArrival);
      expect(_maxScale(tester), moreOrLessEquals(1.0, epsilon: 0.001));
    });

    testWidgets('the SLOW layer also never scales below 1', (tester) async {
      await tester.pumpWidget(
        _arrival(TabArrival.rippleExpand,
            drift: 0.55, duration: Motion.tabBackdrop),
      );
      var minScale = double.infinity;
      for (var ms = 0; ms <= Motion.tabBackdrop.inMilliseconds; ms += 20) {
        await tester.pump(Duration(milliseconds: 20));
        final s = _minScale(tester);
        if (s < minScale) minScale = s;
      }
      expect(minScale, greaterThanOrEqualTo(1.0));
    });
  });

  group('the elements stagger instead of moving as one block', () {
    testWidgets('a later row is BEHIND an earlier one — the offset differs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  StaggerIn(index: i, child: SizedBox(height: 40, width: 300, child: Text('row$i'))),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 80));

      double offsetOf(int i) {
        final t = tester.widget<Transform>(
          find
              .descendant(
                of: find.byKey(ValueKey('stagger-$i')),
                matching: find.byType(Transform),
              )
              .first,
        );
        return t.transform.getTranslation().x;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (var i = 0; i < 5; i++)
                  StaggerIn(
                    key: ValueKey('stagger-$i'),
                    index: i,
                    child: SizedBox(height: 40, width: 300, child: Text('row$i')),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      final first = offsetOf(0);
      final later = offsetOf(4);
      expect(first, isNot(moreOrLessEquals(later, epsilon: 0.5)),
          reason: 'every row is at the same offset — nothing is staggering');
    });

    testWidgets('a row is legible almost immediately, not after its delay',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggerIn(index: 0, child: const SizedBox(height: 40, width: 300)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 140));

      final wrappers = find.descendant(
        of: find.byType(StaggerIn),
        matching: find.byType(Opacity),
      );
      expect(
        wrappers,
        findsNothing,
        reason: 'the row still carries its entrance wrapper, so it is still faded or paying for a layer',
      );
    });

    testWidgets('the delay is CAPPED, so a long list does not arrive late',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                StaggerIn(index: 14, child: const SizedBox(width: 50, height: 40)),
                StaggerIn(index: 40, child: const SizedBox(width: 50, height: 40)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      final opacities =
          tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();

      expect(opacities[0], moreOrLessEquals(opacities[1], epsilon: 0.05),
          reason: 'the stagger delay is not capped');
    });
  });
}
