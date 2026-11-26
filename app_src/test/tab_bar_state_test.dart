library;

// The bar used to say "you are here" three times: the label in accent ink, the
// icon a size larger, and a 2px skewed accent rule under the label. The rule is
// gone because it was the only one of the three that read as something else — a
// bottom border of the bar, or on top of it, the mini player's own edge.
//
// Which makes this file necessary: removing one of three cues is one commit away
// from removing the last one, and a bar where the chosen tab looks like the
// others is a navigation you have to guess at. So the rule must stay gone, and
// the two cues that remain must still be measurably different between the tab
// you are on and the ones you are not.

import 'package:flutter/material.dart';

import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/theme/skin.dart';

const _skinId = SkinId.amber;

Future<void> _open(WidgetTester tester, AppTab current) async {
  tester.view.physicalSize = const Size(400, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: TabBarView2(
          skin: skinFor(_skinId),
          current: current,
          onSelect: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _in(AppTab tab, Finder matching) => find.descendant(
  of: find.byKey(ValueKey('tab-${tab.name}')),
  matching: matching,
);

Color _labelColour(WidgetTester tester, AppTab tab) {
  final text = tester.widget<Text>(_in(tab, find.byType(Text)));
  return text.style!.color!;
}

double _iconScale(WidgetTester tester, AppTab tab) {
  // Pressable scales on press as well, so this reads the icon's own scale, the
  // one under the centred column.
  final scale = tester.widget<AnimatedScale>(
    find.descendant(
      of: _in(tab, find.byType(Center)),
      matching: find.byType(AnimatedScale),
    ),
  );
  return scale.scale;
}

void main() {
  testWidgets('the chosen tab is marked by ink and size, not by a rule', (
    tester,
  ) async {
    await _open(tester, AppTab.library);

    final rule = find.descendant(
      of: find.byType(TabBarView2),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.minHeight == 2 &&
            w.constraints?.maxHeight == 2,
      ),
    );
    expect(
      rule,
      findsNothing,
      reason:
          'The 2px accent underline is back under the chosen tab. It was '
          'removed on purpose: it read as a border of the bar rather than as '
          'the state of a tab, and the label and icon already carry that.',
    );

    expect(
      _labelColour(tester, AppTab.library),
      isNot(_labelColour(tester, AppTab.home)),
      reason:
          'The tab you are on reads the same colour as the tabs you are '
          'not on. With the underline gone that leaves the bar with no state '
          'at all.',
    );
    expect(
      _labelColour(tester, AppTab.library),
      isNot(_labelColour(tester, AppTab.settings)),
      reason: 'Same as above for the other neighbour.',
    );
  });

  testWidgets('the chosen tab sits larger than the ones beside it', (
    tester,
  ) async {
    await _open(tester, AppTab.home);

    expect(
      _iconScale(tester, AppTab.home),
      greaterThan(_iconScale(tester, AppTab.library)),
      reason:
          'The active tab no longer scales up, so the only remaining '
          'difference is colour — which is the cue that vanishes first in '
          'greyscale and for some kinds of colour blindness.',
    );
  });

  testWidgets('the chosen tab is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, AppTab.settings);

    final node = tester.getSemantics(
      find.byKey(const ValueKey('tab-settings')),
    );
    expect(
      node.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
      reason:
          'A screen reader user cannot tell which tab they are on: the '
          'colour and the size are both invisible to them.',
    );
    final other = tester.getSemantics(find.byKey(const ValueKey('tab-home')));
    expect(
      other.getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
      reason:
          'Every tab announces itself as selected, which is the same as '
          'none of them doing so.',
    );
    handle.dispose();
  });
}
