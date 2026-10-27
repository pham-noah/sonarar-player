library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/screens/library_browser.dart';
import 'package:sonarar/theme/skin.dart';

Playlist _list() => Playlist(id: 'p3r', name: 'Persona 5 Royal', trackIds: const ['a']);

Widget _row({required bool pinned}) => MaterialApp(
      home: Material(
        child: SizedBox(
          width: 400,
          child: PlaylistRow(
            skin: kSkinCrimson,
            playlist: _list(),
            cover: null,
            pinned: pinned,
            onOpen: () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('the pin mark is drawn between the cover and the name', (tester) async {
    await tester.pumpWidget(_row(pinned: true));
    await tester.pumpAndSettle();

    final pin = find.byIcon(Icons.push_pin_rounded);
    expect(pin, findsOneWidget, reason: 'a pinned row drew no pin mark at all');

    final name = find.text('Persona 5 Royal');
    expect(name, findsOneWidget);

    final pinX = tester.getCenter(pin).dx;
    final nameX = tester.getCenter(name).dx;

    expect(pinX, lessThan(nameX),
        reason: 'the pin (x=$pinX) is not LEFT of the name (x=$nameX) — it is still inside the name column, '
            'which is the arrangement he asked to have changed');
  });

  testWidgets('an unpinned row draws no pin mark', (tester) async {
    await tester.pumpWidget(_row(pinned: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_rounded), findsNothing,
        reason: 'an unpinned playlist is wearing a pin mark');
  });
}
