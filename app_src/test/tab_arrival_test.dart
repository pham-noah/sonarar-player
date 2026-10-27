@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/tab_motif.dart';

Widget _host(TabArrival arrival, {Key? key}) => MaterialApp(
      home: Scaffold(
        body: TabArrivalView(
          key: key ?? const ValueKey('t'),
          arrival: arrival,
          child: const SizedBox(width: 200, height: 200),
        ),
      ),
    );

void main() {
  group('the device is derived from the motif, not picked in the shell', () {
    test('each motif gets its own arrival', () {
      expect(TabArrival.forMotif(TabMotif.zigzag), TabArrival.zigzagSlant);
      expect(TabArrival.forMotif(TabMotif.sweep), TabArrival.sweepFromSide);
      expect(TabArrival.forMotif(TabMotif.ripple), TabArrival.rippleExpand);

      expect(TabArrival.forMotif(TabMotif.none), TabArrival.settle);
    });

    test('three motifs means three DISTINCT arrivals', () {
      final perMotif = [
        TabMotif.zigzag,
        TabMotif.sweep,
        TabMotif.ripple,
      ].map(TabArrival.forMotif).toSet();
      expect(perMotif, hasLength(3));
    });
  });

  group('the backdrop lags the content — two speeds, per P5', () {
    double dxOf(WidgetTester tester, String key) {
      final tf = tester.widget<Transform>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Transform),
            )
            .first,
      );
      return tf.transform.getTranslation().x;
    }

    Future<void> pumpLayered(WidgetTester tester) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [

                  TabArrivalView(
                    key: const ValueKey('bg'),
                    arrival: TabArrival.zigzagSlant,
                    duration: Motion.tabBackdrop,
                    drift: 0.55,

                    hardSnap: false,
                    child: const SizedBox(width: 100, height: 100),
                  ),

                  TabArrivalView(
                    key: const ValueKey('fg'),
                    arrival: TabArrival.zigzagSlant,
                    child: const SizedBox(width: 100, height: 100),
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('the content is DONE while the backdrop is still settling',
        (tester) async {
      await pumpLayered(tester);
      await tester.pump(Motion.tabArrival);

      expect(dxOf(tester, 'fg').abs(), lessThanOrEqualTo(0.5),
          reason: 'the content should have finished travelling');
      expect(dxOf(tester, 'bg').abs(), greaterThan(0.5),
          reason: 'the backdrop finished as fast as the content — the layering is gone');
    });

    testWidgets('the backdrop travels LESS far than the content', (tester) async {
      await pumpLayered(tester);

      final bg = dxOf(tester, 'bg').abs();
      final fg = dxOf(tester, 'fg').abs();
      expect(bg, greaterThan(0), reason: 'the backdrop never moved');
      expect(fg, greaterThan(0), reason: 'the content never moved');
      expect(bg, lessThan(fg),
          reason: 'the backdrop drifted as far as the content — it will compete with it');
    });

    testWidgets('both are fully faded long before they stop moving',
        (tester) async {
      await pumpLayered(tester);
      await tester.pump(Motion.tabBackdrop * 0.6);

      final opacities =
          tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
      expect(opacities.every((o) => o >= 0.99), isTrue,
          reason: 'a layer is still fading while the other has arrived');
      expect(dxOf(tester, 'bg').abs(), greaterThan(0.5),
          reason: 'the backdrop stopped early — there is no layering left to see');
    });
  });

  group('it plays, then stops', () {
    testWidgets('it is FULLY LEGIBLE on the first frame — no hidden window',
        (tester) async {
      await tester.pumpWidget(_host(TabArrival.zigzagSlant));

      expect(
        find.descendant(
          of: find.byType(TabArrivalView),
          matching: find.byType(Opacity),
        ),
        findsNothing,
        reason: 'the arrival dims the tab, which is the flash',
      );

      await tester.pump(Motion.tabArrival);
      expect(
        find.descendant(
          of: find.byType(TabArrivalView),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('the offset is GONE at the end, so nothing stays displaced',
        (tester) async {
      await tester.pumpWidget(_host(TabArrival.sweepFromSide));
      await tester.pump(Motion.tabArrival);

      final tf = tester.widget<Transform>(find.byType(Transform).first);
      expect(tf.transform.getTranslation().x, moreOrLessEquals(0, epsilon: 0.01));
      expect(tf.transform.getTranslation().y, moreOrLessEquals(0, epsilon: 0.01));
    });

    testWidgets('it does not replay when the parent merely rebuilds',
        (tester) async {
      await tester.pumpWidget(_host(TabArrival.zigzagSlant));
      await tester.pump(Motion.tabArrival);

      double travel() => tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform.getTranslation().x.abs() + t.transform.getTranslation().y.abs())
          .fold<double>(0, (a, b) => a > b ? a : b);

      expect(travel(), lessThan(0.5), reason: 'the arrival never came to rest');

      await tester.pumpWidget(_host(TabArrival.zigzagSlant));
      await tester.pump();
      expect(travel(), lessThan(0.5), reason: 'a rebuild restarted the entrance');
    });

    testWidgets('a NEW key plays it again, which is what a tab change is',
        (tester) async {
      await tester.pumpWidget(_host(TabArrival.zigzagSlant, key: const ValueKey('a')));
      await tester.pump(Motion.tabArrival);

      await tester.pumpWidget(_host(TabArrival.sweepFromSide, key: const ValueKey('b')));
      await tester.pump();

      final transform = tester
          .widgetList<Transform>(find.byType(Transform))
          .map((t) => t.transform.getTranslation().x)
          .where((x) => x.abs() > 0.5);
      expect(transform, isNotEmpty,
          reason: 'switching tabs should play the new tab\'s own arrival');

      expect(
        find.descendant(of: find.byType(TabArrivalView), matching: find.byType(Opacity)),
        findsNothing,
        reason: 'the new tab is dimmed, which is the flash',
      );
    });

    testWidgets('the side device arrives from the DIRECTION travelled',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TabArrivalView(
            key: const ValueKey('f'),
            arrival: TabArrival.sweepFromSide,
            travel: TabTravel.forwards,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 24));
      final fwd = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .getTranslation();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TabArrivalView(
            key: const ValueKey('b'),
            arrival: TabArrival.sweepFromSide,
            travel: TabTravel.backwards,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 24));
      final back = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .getTranslation();

      expect(fwd.x.sign, isNot(back.x.sign),
          reason: 'forwards and backwards arrived from the same side');
    });

    testWidgets('each arrival moves along its OWN axis', (tester) async {
      await tester.pumpWidget(_host(TabArrival.zigzagSlant));
      await tester.pump(const Duration(milliseconds: 24));
      final zig = tester.widget<Transform>(find.byType(Transform).first);
      expect(zig.transform.getTranslation().x.abs(), greaterThan(0));
      expect(zig.transform.getTranslation().y.abs(), moreOrLessEquals(0, epsilon: 0.01),
          reason: 'zigzag should travel on one axis only');

      await tester.pumpWidget(_host(TabArrival.rippleExpand, key: const ValueKey('r')));
      await tester.pump(const Duration(milliseconds: 24));
      final ripple = tester.widget<Transform>(find.byType(Transform).first);
      expect(ripple.transform.getTranslation().x.abs(), greaterThan(0),
          reason: 'the ripple comes from a corner, so it moves on both axes');
      expect(ripple.transform.getTranslation().y.abs(), greaterThan(0));
    });
  });
}
