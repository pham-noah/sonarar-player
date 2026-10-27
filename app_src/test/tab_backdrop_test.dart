@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/tab_motif.dart';

void main() {
  testWidgets('TabBackdrop does NOT return a Positioned itself', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabBackdrop(skin: kSkinCrimson, motif: TabMotif.zigzag),
        ),
      ),
    );
    expect(find.byType(Positioned), findsNothing,
        reason: 'TabBackdrop is positioning itself again — bury it in any wrapper and the '
            'backdrop stops painting, which is the white edge');
  });

  testWidgets('it can be wrapped and still renders — the case that broke',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.8,
                  child: TabBackdrop(skin: kSkinCrimson, motif: TabMotif.zigzag),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull,
        reason: 'wrapping the backdrop threw at runtime');
    expect(find.byType(CustomPaint), findsWidgets,
        reason: 'the wrapped backdrop did not paint');
  });

  testWidgets('a motif of none still draws nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TabBackdrop(skin: kSkinCrimson, motif: TabMotif.none),
        ),
      ),
    );

    expect(
      find.descendant(of: find.byType(TabBackdrop), matching: find.byType(CustomPaint)),
      findsNothing,
    );
  });
}
