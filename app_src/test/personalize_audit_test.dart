library;

// The Personalization screen is the app's densest surface: four tabs, a dozen
// sliders, and two palettes of colours drawn as bare containers. None of it was
// ever measured — the five-screen text-scale matrix and the semantics probes
// both skipped it — so a control that announced nothing and a row that overflowed
// could sit there indefinitely.
//
// This file measures the two things that were invisible:
//
//   1. Nothing overflows at 1.0x, 1.3x or 2.0x on any of the four tabs. The
//      failures it was written against: the header title asking 0.2dp more than
//      the row had at 1.3x in Finnish, the ART tab's three chips wanting 204dp
//      more than the column had at 2.0x, and the 216dp preview card overflowing
//      by 29dp at 2.0x on all four tabs.
//   2. Every tap and long-press target has a name. The failures it was written
//      against: the back arrow, both palette rows (eighteen unnamed buttons),
//      four reorder arrows, and the switch on every toggle row — fifty-three
//      unnamed controls in total.
//
// A screen reader user can now hear which colour of which palette they are on and
// whether it is the one in force; that is the difference between personalisation
// and a wall of "button".

import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/screens/personalize_screen.dart';

const _tabs = ['themes', 'look', 'art', 'home'];

Future<void> _open(WidgetTester tester, String tab, {double scale = 1.0}) async {
  tester.view.physicalSize = const Size(420, 860) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(home: Scaffold(body: PersonalizeScreen(state: AppState()))),
  ));
  await tester.pump();
  if (tab != 'themes') {
    await tester.tap(find.byKey(Key('personalize-tab-$tab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Every node a finger or a screen reader can act on, with the name it would
/// announce. Walks the real semantics tree, so a label that exists only as a
/// `Tooltip` or an `Icon` does not count.
List<String> _unnamed(WidgetTester tester) {
  final owner = tester.binding.renderViews.first.owner!.semanticsOwner;
  if (owner == null) throw StateError('ensureSemantics() was not called');
  final found = <String>[];

  String? nameOf(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.label.trim().isNotEmpty) return data.label.trim();
    if (data.value.trim().isNotEmpty) return data.value.trim();
    String? child;
    node.visitChildren((c) {
      child ??= nameOf(c);
      return child == null;
    });
    return child;
  }

  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    final actionable = data.hasAction(SemanticsAction.tap) ||
        data.hasAction(SemanticsAction.longPress);
    if (actionable && (nameOf(node) ?? '').isEmpty) {
      found.add('${node.rect.width.round()}x${node.rect.height.round()}'
          '${data.hasAction(SemanticsAction.tap) ? ' tap' : ''}'
          '${data.hasAction(SemanticsAction.longPress) ? ' long-press' : ''}');
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return found;
}

void main() {
  group('personalisation, at the sizes a phone actually reaches', () {
    for (final scale in const [1.0, 1.3, 2.0]) {
      for (final tab in _tabs) {
        testWidgets('$tab tab has no overflowing row at ${scale}x',
            (tester) async {
          final caught = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) => caught.add(details.toString());
          await _open(tester, tab, scale: scale);
          FlutterError.onError = previous;

          final overflows = caught
              .where((text) => text.contains('overflowed'))
              .map((text) => text.split('\n').firstWhere(
                  (line) => line.contains('overflowed'),
                  orElse: () => text.split('\n').first))
              .toList();
          expect(overflows, isEmpty,
              reason: 'The $tab tab of Personalization overflows at ${scale}x '
                  'text on a 420dp-wide phone. Layouts it was written against: '
                  'the header title 0.2dp over in Finnish at 1.3x, the ART chips '
                  '204dp over at 2.0x, and the 216dp preview card 29dp over at '
                  '2.0x. Offenders:\n${overflows.join('\n')}');
        });
      }
    }

    for (final tab in _tabs) {
      testWidgets('$tab tab names every control it offers', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(tester, tab);
        final found = _unnamed(tester);
        handle.dispose();

        expect(found, isEmpty,
            reason: 'The $tab tab of Personalization offers ${found.length} '
                'control(s) with no accessible name. A screen reader announces '
                'them as "button" and nothing else. Offenders (size, action):\n'
                '${found.join('\n')}');
      });
    }

    testWidgets('the palettes say which colour of which palette, and which is on',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, 'look');

      // Every node that announces something, as the screen reader sees it. A
      // check mark drawn inside a swatch is not a state anyone can hear, so the
      // colour in force has to carry `selected`.
      List<SemanticsNode> nodes() {
        final all = <SemanticsNode>[];
        void walk(SemanticsNode node) {
          if (node.getSemanticsData().label.trim().isNotEmpty) all.add(node);
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
        return all;
      }

      String nameOf(SemanticsNode node) => node.getSemanticsData().label.trim();
      bool selected(SemanticsNode node) {
        // `SemanticsFlags` carries the selected/checked states; `hasFlag` is the
        // deprecated way to ask, so the collection is read directly.
        final flags = node.getSemanticsData().flagsCollection;
        return flags.isSelected == Tristate.isTrue || flags.isChecked == CheckedState.isTrue;
      }

      final accents = nodes().where((n) => nameOf(n).startsWith('ACCENT, ')).toList();
      handle.dispose();

      expect(accents, isNotEmpty,
          reason: 'No accent swatch announces which colour of the palette it is, '
              'so a screen reader user cannot pick a hue — eighteen identical '
              'buttons was the defect.');
      // The row builds lazily, so this checks the first of them, not all
      // eighteen: what matters is that a swatch announces a place in the palette
      // rather than nothing.
      expect(accents.map(nameOf), contains('ACCENT, 1 of 18'),
          reason: 'The palette does not say where each colour sits in it. '
              'Announced instead: ${accents.map(nameOf).join(', ')}');

      // Nothing is manual until a colour is tapped, so the theme's own accent is
      // what is in force — and it has to say so, or the picker reads as "nothing
      // chosen" when a theme accent is exactly what is on.
      final themed = nodes()
          .where((n) => nameOf(n) == 'Theme accent')
          .toList();
      expect(themed.where(selected).length, 1,
          reason: 'With no colour picked, the theme accent is what is in force, and '
              'the chip that clears the choice did not announce itself as selected.');
      expect(accents.where(selected), isEmpty,
          reason: 'No accent colour is picked, so none of the eighteen swatches '
              'should announce itself as the current one.');

      // Pick the third swatch: it becomes the selected one and the theme chip
      // steps back — the state the picker exists to communicate.
      final handle2 = tester.ensureSemantics();
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      final target = accents.firstWhere((n) => nameOf(n) == 'ACCENT, 3 of 18');
      // Invoked the way a screen reader invokes it — the semantics action, not a
      // finger on a rectangle — because that is the path this fix is for.
      owner.performAction(target.id, SemanticsAction.tap);
      await tester.pump();
      final after = nodes();
      handle2.dispose();

      expect(
        after.where((n) => nameOf(n).startsWith('ACCENT, ') && selected(n)).map(nameOf),
        ['ACCENT, 3 of 18'],
        reason: 'After choosing a colour the picker must announce exactly that '
            'colour as the current one, and the theme chip must no longer claim to '
            'be. It announced: '
            '${after.where(selected).map(nameOf).join(', ')}',
      );
    });
  });
}
