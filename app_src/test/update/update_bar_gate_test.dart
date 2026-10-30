import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/update/update_bar.dart';

/// The switch in settings has to stop the check, not just hide its result.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('off means the check never runs', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(UpdateBar(
      skin: kSkinAbyss,
      enabled: false,
      check: () async {
        calls++;
        return null;
      },
    )));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(UpdateBar), findsOneWidget);
  });

  testWidgets('on means it asks once, after the first frame', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(UpdateBar(
      skin: kSkinAbyss,
      check: () async {
        calls++;
        return null;
      },
    )));
    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
