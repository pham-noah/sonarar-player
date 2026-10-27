library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/tab_motif.dart';

Future<double> _firstOffset(WidgetTester tester, MotionSpec? spec) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Stack(
      children: [
        TabArrivalView(
          arrival: TabArrival.sweepFromSide,
          duration: spec?.tabTransition ?? const Duration(milliseconds: 420),
          motion: spec,
          child: SizedBox(key: key, width: 100, height: 100),
        ),
      ],
    ),
  ));
  await tester.pump();
  final first = tester.getTopLeft(find.byKey(key)).dx;

  await tester.pumpAndSettle();
  expect(tester.getTopLeft(find.byKey(key)).dx, moreOrLessEquals(0, epsilon: 0.01),
      reason: 'the arrival never settled — the content rests displaced');

  return first;
}

void main() {
  group('the spec says what a layout does', () {
    test('Persona is untouched', () {
      expect(MotionSpec.persona.tabTransition, const Duration(milliseconds: 420));
      expect(MotionSpec.persona.arrivalAmplitude, 1.0);
      expect(MotionSpec.persona.backdropFactor, 1.65);

      for (final t in const [0.25, 0.5, 0.75, 0.9]) {
        expect(MotionSpec.persona.arrivalCurve.transform(t),
            MotionCurve.arrival.transform(t));
      }
      expect(
          [
            for (var i = 0; i <= 100; i++)
              MotionSpec.persona.arrivalCurve.transform(i / 100)
          ].reduce((a, b) => a > b ? a : b),
          greaterThan(1.0),
          reason: 'Persona no longer overshoots — its arrival lost the landing');
    });

    test('the restrained layouts move less, and less abruptly', () {
      expect(MotionSpec.restrained.tabTransition,
          const Duration(milliseconds: 260));

      expect(MotionSpec.restrained.arrivalAmplitude, greaterThan(0.3),
          reason: 'the restrained layouts went back to barely moving — he asked for closer to Persona');
      expect(MotionSpec.restrained.arrivalAmplitude,
          lessThan(MotionSpec.persona.arrivalAmplitude),
          reason: 'the restrained layouts now move as far as Persona — the layouts are the same again');

      expect(MotionSpec.restrained.backdropFactor,
          lessThan(MotionSpec.persona.backdropFactor));

      for (var i = 0; i <= 100; i++) {
        expect(MotionSpec.restrained.arrivalCurve.transform(i / 100),
            lessThanOrEqualTo(1.0 + 1e-9));
      }
    });
  });

  group('and the arrival obeys it', () {
    testWidgets('Persona travels the full distance', (tester) async {
      final first = await _firstOffset(tester, MotionSpec.persona);

      expect(first, greaterThan(150),
          reason: 'Persona no longer travels — its arrival was flattened');
    });

    testWidgets('Solid and Glass travel part of Persona\'s distance, not all of it',
        (tester) async {
      final first = await _firstOffset(tester, MotionSpec.restrained);
      expect(first, lessThan(140),
          reason: 'the restrained arrival travels Persona\'s whole distance — that is the punch again');
      expect(first, greaterThan(60),
          reason: 'the restrained arrival barely moves — he asked for it CLOSER to Persona, not gone');
    });

    testWidgets('a caller that passes no spec gets Persona, unchanged',
        (tester) async {
      final none = await _firstOffset(tester, null);
      expect(none, greaterThan(150));
    });
  });
}
