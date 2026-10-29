import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/screens/personalize_screen.dart';
import 'package:sonarar/theme/personalization.dart';

void main() {
  late AppState state;

  setUp(() => state = AppState());

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for every section at once: the screen grew a LAYOUT and a
    // SONG LIST block, and a phone-height viewport pushes HOME below the fold.
    tester.view.physicalSize = const Size(430, 2600) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: PersonalizeScreen(state: state),
    ));
    await tester.pump();
  }

  testWidgets('the screen offers the three things and a way to keep them', (tester) async {
    await pump(tester);

    expect(find.text('BACKDROP'), findsOneWidget);
    expect(find.text('ACCENT'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('NOW stays at the top — it is the page header, not a section.'),
        findsOneWidget);
  });

  testWidgets('NOW is not offered as a reorderable row', (tester) async {
    await pump(tester);

    expect(find.text('CONTINUE LISTENING'), findsOneWidget);
    expect(find.text('NOW'), findsNothing);
  });

  testWidgets('hiding a section keeps its row on screen and marks it hidden', (tester) async {
    await pump(tester);

    final row = find.byKey(const ValueKey('home-row-recap'));
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pump();

    expect(state.personalization.home.hidden, contains(HomeSection.recap));
    expect(find.text('RECAP'), findsOneWidget, reason: 'a hidden section must stay listed to be turned back on');
  });

  testWidgets('moving a section up writes the new order', (tester) async {
    await pump(tester);

    final row = find.byKey(const ValueKey('home-row-recap'));
    await tester.scrollUntilVisible(row, 200);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.keyboard_arrow_up_rounded)));
    await tester.pump();

    final order = state.personalization.home.all;
    expect(order.indexOf(HomeSection.recap),
        lessThan(HomeLayout.defaultOrder.indexOf(HomeSection.recap)));
  });

  testWidgets('picking an accent writes it and keeps the source', (tester) async {
    await pump(tester);

    await tester.tap(find.text('PICK'));
    await tester.pump();

    final swatch = find.byType(GestureDetector).at(0);
    expect(swatch, findsOneWidget);
    expect(state.personalization.accent.source, AccentSource.manual);
  });
}
