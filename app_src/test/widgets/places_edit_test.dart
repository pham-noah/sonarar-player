library;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/context/places.dart';
import 'package:sonarar/context/location_service.dart';
import 'package:sonarar/context/poi_service.dart';
import 'package:sonarar/screens/places_screen.dart';
import 'package:sonarar/theme/skin.dart';

PlacesScreen _screen({required PlaceBook book, required ValueChanged<PlaceBook> onChanged}) =>
    PlacesScreen(
      skin: kSkinAbyss,
      places: book,
      here: _here,
      kinds: const {},
      playlists: const ['Evening', 'Rain'],
      poiService: PoiService(client: _DeadClient()),
      onChanged: onChanged,
    );

class _DeadClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 503);
}

const _here = PlaceReading(latitude: 51.5, longitude: -0.1, accuracyMetres: 12);

Future<void> _open(WidgetTester tester, PlaceBook book, ValueChanged<PlaceBook> onChanged) async {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: _screen(book: book, onChanged: onChanged)),
  ));
  await tester.pump();
}

Future<void> _tapPlace(WidgetTester tester, String subtitle) async {
  final row = find.text(subtitle);
  await tester.scrollUntilVisible(row, 60, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a saved place shows its name, its spots and its playlist', (tester) async {
    final book = PlaceBook.empty.upsert(const NamedPlace(
      id: 'gym',
      name: 'Gym',
      anchors: [PlaceAnchor(latitude: 51.5, longitude: -0.1)],
      playlist: 'Evening',
    ));

    await _open(tester, book, (_) {});

    expect(find.text('Gym'), findsWidgets);
    expect(find.textContaining('1 spot'), findsWidgets);
    expect(find.textContaining('Evening'), findsWidgets);
  });

  testWidgets('RENAMING a place rekeys it — the old id must not survive', (tester) async {
    var saved = PlaceBook.empty.upsert(const NamedPlace(
      id: 'gym',
      name: 'Gym',
      anchors: [PlaceAnchor(latitude: 51.5, longitude: -0.1)],
      playlist: 'Evening',
    ));

    await _open(tester, saved, (b) => saved = b);

    await _tapPlace(tester, '1 spot \u00b7 Evening');

    expect(find.text('EDIT THIS PLACE'), findsOneWidget,
        reason: 'tapping a saved place did not open the editor');
    expect(find.text('SAVE CHANGES'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Fitness Centre');
    await tester.pump();

    await tester.tap(find.text('SAVE CHANGES'));
    await tester.pumpAndSettle();

    expect(saved.length, 1, reason: 'the rename made a SECOND place instead of rekeying the first');
    expect(saved.places.first.name, 'Fitness Centre');
    expect(saved.places.first.id, 'fitness_centre',
        reason: 'the id was not re-derived from the new name — every rule still points at "${saved.places.first.id}"');
    expect(saved.places.first.playlist, 'Evening',
        reason: 'the rename dropped the playlist that was already set');
    expect(saved.places.first.anchors, hasLength(1),
        reason: 'the rename dropped the spot');
  });

  testWidgets('a rename does NOT warn about clashing with ITSELF', (tester) async {
    final book = PlaceBook.empty.upsert(const NamedPlace(
      id: 'gym',
      name: 'Gym',
      anchors: [PlaceAnchor(latitude: 51.5, longitude: -0.1)],
    ));

    await _open(tester, book, (_) {});
    await _tapPlace(tester, '1 spot');

    expect(find.textContaining('already have a place by this name'), findsNothing,
        reason: 'the editor warned that the place clashes with its own name');
  });

  testWidgets('NAMING A NEW SPOT does warn when the name is already used', (tester) async {
    final book = PlaceBook.empty.upsert(const NamedPlace(
      id: 'gym',
      name: 'Gym',
      anchors: [PlaceAnchor(latitude: 51.5, longitude: -0.1)],
    ));

    await _open(tester, book, (_) {});

    await tester.tap(find.textContaining('SAVE THIS SPOT').first);
    await tester.pumpAndSettle();

    expect(find.text('NAME THIS SPOT'), findsOneWidget,
        reason: 'the new-spot path did not open');

    await tester.enterText(find.byType(TextField).first, 'Gym');
    await tester.pump();
    expect(find.textContaining('already have a place by this name'), findsOneWidget,
        reason: 'reusing a name gave no indication that it grows the existing place');
  });
}
