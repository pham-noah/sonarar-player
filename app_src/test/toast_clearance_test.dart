library;

// A toast pinned to the bottom edge sits on the two things a thumb reaches for:
// the mini player and the tab row. For the eight seconds a long undo bar is up
// (and four for the short ones) every tap in the bottom band lands on the toast
// instead — the bar you were about to use is simply not there, and nothing on
// screen says why.
//
// Measured on the real shell at 420x860: the toast's bottom edge was 24dp off the
// floor, which is inside the tab row.
//
// Two halves, because either alone can pass for the wrong reason: the shell
// publishes the height of its bars, and a toast raised from a screen inside the
// shell reads it. The shell's own toasts cannot read it (its context is above the
// widget that publishes it) and pass the number instead, which the last test here
// pins on the booted app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/toasts.dart';

void main() {
  testWidgets('a toast keeps clear of the bars the shell publishes',
      (tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ToastClearance(
        height: 120,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => toast(context, 'Cleared 3 from the queue'),
                child: const Text('raise'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('raise'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Cleared 3 from the queue'));
    expect(rect.bottom, lessThanOrEqualTo(860 - 120),
        reason: 'the toast ends at ${rect.bottom} on an 860-high screen with a '
            '120-high bar: it is on top of the bar and eating its taps');
  });

  testWidgets('and still sits at the bottom when there is nothing to clear',
      (tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => toast(context, 'Saved'),
              child: const Text('raise'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('raise'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Saved'));
    expect(rect.bottom, greaterThan(860 - 60),
        reason: 'with no bars published the toast must not float up the screen; '
            'a fixed inset would move every toast in the app');
  });

  testWidgets('the shell raises its own toasts above its own bars',
      (tester) async {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // The number the shell computes for itself, reproduced: the tab row's height
    // plus air. If the shell went back to passing nothing, its toasts would read
    // 0 from the scope and land at the bottom edge again.
    await tester.pumpWidget(MaterialApp(
      home: ToastClearance(
        height: LayoutSpec.tabBarHeight + 8,
        child: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => toast(context, 'Queue cleared',
                    clearance: LayoutSpec.tabBarHeight + 8),
                child: const Text('raise'),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('raise'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Queue cleared'));
    expect(rect.bottom, lessThanOrEqualTo(860 - LayoutSpec.tabBarHeight - 8),
        reason: 'the tab row is ${LayoutSpec.tabBarHeight} tall and the toast '
            'ended at ${rect.bottom}');
  });
}
