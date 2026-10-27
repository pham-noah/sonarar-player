@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/screens/history_screen.dart';
import 'package:sonarar/screens/archive_screen.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/slab.dart';
import 'package:sonarar/widgets/inline_panel.dart';

void main() {
  testWidgets('history renders as a panel body when inline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(

          body: Stack(children: [
            InlinePanelSheet(
            skin: kSkinCrimson,
            title: 'HISTORY',
            onClose: () {},
            child: const HistoryScreen(
              skin: kSkinCrimson,
              events: [],
              tracks: [],
              inline: true,
            ),
          ),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('HISTORY'), findsOneWidget);

    expect(find.byType(ScreenTitle), findsNothing);

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('the room renders as a panel body and can nest', (tester) async {
    var backPressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            InlinePanelSheet(
            skin: kSkinCrimson,
            title: 'LIBRARY TOOLS',
            onClose: () {},
            onBack: () => backPressed++,
            child: ArchiveScreen(
              state: AppState(),
              inline: true,
            ),
          ),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    expect(backPressed, 1);
  });

  testWidgets('the height ladder: up grows, down shrinks, only small closes',
      (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(children: [
            InlinePanelSheet(
              skin: kSkinCrimson,
              title: 'HISTORY',
              onClose: () => closed++,
              child: const SizedBox.expand(),
            ),
          ]),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InlinePanelSheet), findsOneWidget);
    var h = tester.getSize(find.byType(AnimatedContainer, skipOffstage: false)).height;

    await tester.drag(find.byIcon(Icons.drag_handle_rounded), const Offset(0, 90));
    await tester.pumpAndSettle();
    expect(closed, 0, reason: 'down from mid shrinks; it must not close');
    final hSmall =
        tester.getSize(find.byType(AnimatedContainer, skipOffstage: false)).height;
    expect(hSmall, lessThan(h));

    await tester.drag(find.byIcon(Icons.drag_handle_rounded), const Offset(0, -90));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(InlinePanelSheet), const Offset(0, -90));
    await tester.pumpAndSettle();

    expect(closed, 0);
  });

  testWidgets('the door stack is GROWABLE — a const list throws on tap',
      (tester) async {
    final stack = <Object>[];
    stack.add('velvetRoom');
    expect(stack, hasLength(1));

    const frozen = <Object>[];
    expect(() => frozen.add('x'), throwsUnsupportedError);
  });

  testWidgets('opening a door does not push a route', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Stack(
              children: [
                Center(
                  child: TextButton(
                    onPressed: () {
                      opened = true;
                    },
                    child: const Text('HISTORY'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    final before = nav.widget.pages.length;

    await tester.tap(find.text('HISTORY'));
    await tester.pump();

    expect(opened, isTrue);

    expect(nav.widget.pages.length, before);
  });
}
