import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/update/update_bar.dart';
import 'package:sonarar/update/update_feed.dart';
import 'package:sonarar/update/update_service.dart';

/// The switch in settings has to stop the check, not just hide its result.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  setUp(() => offerUpdate(null));
  tearDown(() => offerUpdate(null));

  const offered = AppUpdate(
    version: '9.9.9',
    build: 99,
    apkUrl: 'https://example.test/a.apk',
    notesUrl: 'https://example.test/n',
    sizeBytes: 1,
    sha256: 'abc',
  );

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

  testWidgets('a manual offer shows even when the automatic check is off',
      (tester) async {
    await tester.pumpWidget(host(UpdateBar(
      skin: kSkinAbyss,
      enabled: false,
      check: () async => null,
    )));
    await tester.pumpAndSettle();

    // The switch is off, so nothing has been offered yet and no row is drawn.
    expect(find.text('UPDATE'), findsNothing);

    offerUpdate(offered);
    await tester.pump();

    expect(find.text('UPDATE'), findsOneWidget,
        reason: 'CHECK NOW must not point at a banner that does not exist');
    expect(find.textContaining('9.9.9'), findsOneWidget);
  });

  testWidgets('withdrawing the offer takes the row away again', (tester) async {
    await tester.pumpWidget(host(UpdateBar(
      skin: kSkinAbyss,
      enabled: false,
      check: () async => null,
    )));
    offerUpdate(offered);
    await tester.pump();
    expect(find.text('UPDATE'), findsOneWidget);

    offerUpdate(null);
    await tester.pump();

    expect(find.text('UPDATE'), findsNothing, reason: 'a withdrawal withdraws');
  });
}
