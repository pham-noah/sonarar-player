@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/tab_motif.dart';
import 'package:sonarar/widgets/stagger_in.dart';

({double dx, double dy, double scaleFrom}) _geo(StaggerStyle s) =>
    staggerGeometry(s);

void main() {
  group('every tab staggers DIFFERENTLY', () {
    test('the four styles are four distinct motions', () {
      final shapes = StaggerStyle.values
          .map((s) {
            final g = _geo(s);
            return '${g.dx},${g.dy},${g.scaleFrom}';
          })
          .toSet();
      expect(shapes, hasLength(4),
          reason: 'two tabs share a motion — the difference is cosmetic');
    });

    test('they differ in KIND, not only in direction', () {
      final shelf = _geo(StaggerStyle.shelf);
      final drop = _geo(StaggerStyle.drop);
      final stamp = _geo(StaggerStyle.stamp);

      expect(shelf.dx, isNot(0), reason: 'the shelf should travel horizontally');
      expect(shelf.dy, 0, reason: 'the shelf should not travel vertically');

      expect(drop.dy, isNot(0), reason: 'the drop should travel vertically');
      expect(drop.dx, 0, reason: 'the drop should not travel horizontally');

      expect(stamp.dx, 0);
      expect(stamp.dy, 0);
      expect(stamp.scaleFrom, lessThan(0.9),
          reason: 'the stamp needs a real scale to be visible without travel');
    });

    test('each style has its own RHYTHM too', () {
      final steps = StaggerStyle.values.map(staggerStepFor).toSet();
      expect(steps, hasLength(4), reason: 'two tabs stagger at the same rate');
    });
  });

  group('a caller can name its OWN direction', () {
    testWidgets('the overrides replace the travel but keep the scale',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggerIn(
              index: 0,
              style: StaggerStyle.rise,
              overrideDx: 190,
              overrideDy: -22,
              child: const SizedBox(width: 200, height: 40),
            ),
          ),
        ),
      );

      final t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(StaggerIn),
              matching: find.byType(Transform),
            )
            .first,
      );
      final tr = t.transform.getTranslation();
      expect(tr.x, greaterThan(0), reason: 'it should start to the right');
      expect(tr.y, lessThan(0), reason: 'it should start above');
    });

    testWidgets('an override is not needed — the style still works alone',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggerIn(
              index: 0,
              style: StaggerStyle.rise,
              child: const SizedBox(width: 200, height: 40),
            ),
          ),
        ),
      );
      final t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(StaggerIn),
              matching: find.byType(Transform),
            )
            .first,
      );
      final tr = t.transform.getTranslation();
      expect(tr.x, moreOrLessEquals(0, epsilon: 0.01),
          reason: 'rise should not travel horizontally on its own');
      expect(tr.y, greaterThan(0), reason: 'rise comes from below');
    });
  });

  group('the page is never white', () {
    testWidgets('the shelf travels on X only, so no vertical gap opens',
        (tester) async {
      expect(_geo(StaggerStyle.shelf).dy, 0);
      expect(_geo(StaggerStyle.stamp).dy, 0);
      expect(_geo(StaggerStyle.stamp).dx, 0);
    });

    testWidgets('a stagging row rests at exactly 1.0 and no offset',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggerIn(
              index: 0,
              style: StaggerStyle.stamp,
              child: const SizedBox(width: 300, height: 40),
            ),
          ),
        ),
      );
      await tester.pump(Motion.stagger);
      await tester.pump(const Duration(milliseconds: 400));

      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      expect(transforms, isNotEmpty);
      for (final t in transforms) {
        final m = t.transform;
        expect(m.getMaxScaleOnAxis(), moreOrLessEquals(1.0, epsilon: 0.001));
        expect(m.getTranslation().x, moreOrLessEquals(0, epsilon: 0.01));
        expect(m.getTranslation().y, moreOrLessEquals(0, epsilon: 0.01));
      }
    });
  });

  group('the tab arrival still settles', () {
    testWidgets('nothing is displaced once the arrival is done', (tester) async {
      for (final arrival in TabArrival.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TabArrivalView(
                key: ValueKey(arrival.name),
                arrival: arrival,
                child: const SizedBox(width: 400, height: 400),
              ),
            ),
          ),
        );
        await tester.pump(Motion.tabArrival);
        await tester.pump(const Duration(milliseconds: 400));

        final m = tester
            .widgetList<Transform>(find.byType(Transform))
            .first
            .transform;
        expect(m.getTranslation().x.abs(), lessThan(0.5), reason: arrival.name);
        expect(m.getTranslation().y.abs(), lessThan(0.5), reason: arrival.name);
      }
    });
  });
}
