@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/screens/library_browser.dart';
import 'package:sonarar/theme/skin.dart';

Future<void> _pump(WidgetTester tester, LibraryView current,
    {LibraryView? picked}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LibraryBrowserBar(
          skin: kSkinCrimson,
          current: current,
          pickedView: picked,
          onSelect: (_) {},
          playlistCount: 0,
          artistCount: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

Color _fillOf(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.text(label), matching: find.byType(Container))
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return decoration.color!;
}

Color _labelColour(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color!;

void main() {
  testWidgets('the ACTIVE chip is far more solid than the inactive one',
      (tester) async {
    await _pump(tester, LibraryView.artists, picked: LibraryView.artists);

    final active = _fillOf(tester, 'ARTISTS');
    final inactive = _fillOf(tester, 'PLAYLISTS');

    expect(active.a, greaterThan(0.8),
        reason: 'the selected chip is too faint to read as the selection');
    expect(inactive.a, lessThan(0.6),
        reason: 'the unselected chip is opaque again — he asked for it to stay translucent');
    expect(active.a - inactive.a, greaterThan(0.3),
        reason: 'the two states are too close to be told apart');
  });

  testWidgets('the chip is still TRANSLUCENT, as he asked', (tester) async {
    await _pump(tester, LibraryView.playlists);
    expect(_fillOf(tester, 'ARTISTS').a, lessThan(0.6));
    expect(_fillOf(tester, 'PLAYLISTS').a, lessThan(0.6),
        reason: 'PLAYLISTS is filled on arrival again — that is the "default filter" he reported');
  });

  testWidgets('an UNSELECTED label is the bright one, not the ghosted one',
      (tester) async {
    await _pump(tester, LibraryView.playlists);
    expect(_labelColour(tester, 'ARTISTS'), kSkinCrimson.textPrimary,
        reason: 'the unselected label is back to the ghosted colour');
  });

  testWidgets('the selection follows `current`, not a fixed chip', (tester) async {
    await _pump(tester, LibraryView.artists, picked: LibraryView.artists);
    expect(_fillOf(tester, 'ARTISTS').a, greaterThan(0.8));
    expect(_fillOf(tester, 'PLAYLISTS').a, lessThan(0.6));
  });
}
