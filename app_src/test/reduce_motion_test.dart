library;

// Reduce Motion is a promise the system makes on the user's behalf: "I do not
// want things moving." Until now the app read `MediaQuery.disableAnimations`
// in zero places, so every transition ran anyway — the 90ms press, the 200ms
// morph, the 320ms tab arrival and the 528ms backdrop — and the only way to
// escape the motion was to stop using the app.
//
// These tests assert the app keeps that promise, and they check pixels-as-
// widgets rather than a duration field: the question is not whether a number is
// zero, it is whether the content is standing still in the frame after it
// appears. `StaggerIn` is the sharpest case — the one animation that moves every
// list item at once — so when it is at rest there is no `Opacity` in the tree at
// all and nothing left to run.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/motion.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/stagger_in.dart';
import 'package:sonarar/widgets/toasts.dart';

const _still = MediaQueryData(disableAnimations: true);
const _moving = MediaQueryData(disableAnimations: false);

Future<void> _pump(WidgetTester tester, MediaQueryData media, Widget child) async {
  await tester.pumpWidget(MediaQuery(
    data: media,
    child: MaterialApp(home: Scaffold(body: child)),
  ));
  // One frame only: after this, anything still moving is still moving because
  // the app asked it to.
  await tester.pump();
}

void main() {
  testWidgets('Motion.of is the setting, asked once per animation', (tester) async {
    late Duration still;
    late Duration moving;
    await _pump(
      tester,
      _still,
      Builder(builder: (context) {
        still = Motion.of(context, Motion.screen);
        return const SizedBox.shrink();
      }),
    );
    await _pump(
      tester,
      _moving,
      Builder(builder: (context) {
        moving = Motion.of(context, Motion.screen);
        return const SizedBox.shrink();
      }),
    );

    expect(still, Duration.zero,
        reason: 'a user who turned animations off must get no duration at all; '
            'a 60ms slide is still a slide');
    expect(moving, Motion.screen, reason: 'and everyone else keeps the token');
  });

  testWidgets('a staggered list is simply there', (tester) async {
    await _pump(
      tester,
      _still,
      ListView(
        children: const [
          StaggerIn(index: 0, child: Text('first')),
          StaggerIn(index: 2, child: Text('third')),
        ],
      ),
    );

    expect(find.text('first'), findsOneWidget);
    expect(find.text('third'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing,
        reason: 'at rest StaggerIn returns its child with no Opacity and no '
            'transform; an Opacity here means the list is still sliding in');
  });

  testWidgets('and it still slides when motion is wanted', (tester) async {
    // The counter-test: without it, deleting the animation entirely would pass.
    await _pump(
      tester,
      _moving,
      ListView(children: const [StaggerIn(index: 0, child: Text('first'))]),
    );

    expect(find.byType(Opacity), findsWidgets,
        reason: 'a list that never animates is a different bug, not a fix');
  });

  testWidgets('the undo bar is there rather than fading in', (tester) async {
    for (final (media, expected) in [(_still, 1.0), (_moving, 0.0)]) {
      await tester.pumpWidget(MediaQuery(
        data: media,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => toastUndo(context, kSkinAbyss, 'Cleared', () {}),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pump();

      if (media.disableAnimations) {
        expect(find.byType(SnackBar), findsNothing,
            reason: 'a SnackBar animates itself with Flutter\'s own duration, '
                'which this app cannot shorten — so with motion turned off the '
                'bar has to be the one drawn here');
      }

      // The toast's own fade — not the page route's, which is still at 0 in its
      // first frame and would make both cases read the same.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('Cleared'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, closeTo(expected, 0.01),
          reason: media.disableAnimations
              ? 'with animations off the bar must be fully visible in its first '
                  'frame, not 0.0 of the way through a fade'
              : 'with animations on it must still be fading in at 0.0');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }
  });
}
