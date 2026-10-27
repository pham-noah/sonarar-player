library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/theme/skin.dart';

Future<void> _pump(WidgetTester tester, {required bool showHome}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeFor(kSkinAbyss),
      home: Scaffold(
        body: const SizedBox.shrink(),
        bottomNavigationBar: TabBarView2(
          skin: kSkinAbyss,
          current: AppTab.library,
          showHome: showHome,
          onSelect: (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home is offered when it has something to show', (tester) async {
    await _pump(tester, showHome: true);
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
  });

  testWidgets('Home disappears when there is nothing to put on it',
      (tester) async {
    await _pump(tester, showHome: false);
    expect(find.text('HOME'), findsNothing,
        reason: 'a tab that opens onto an empty page is worse than no tab');
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(find.text('SEARCH'), findsOneWidget);
  });

  testWidgets('the remaining tabs still share the bar', (tester) async {
    await _pump(tester, showHome: false);
    final library = tester.getRect(find.text('LIBRARY'));
    final search = tester.getRect(find.text('SEARCH'));
    expect(library.center.dx, lessThan(search.center.dx));
  });
}
