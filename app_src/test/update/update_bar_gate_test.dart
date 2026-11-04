import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/update/update_bar.dart';
import 'package:sonarar/update/update_service.dart';
import 'package:sonarar/update/update_ui.dart';

/// The switch in settings has to stop the check, not just hide its result — and the
/// bar has to be a view of the shell's one update flow, not a second copy of it.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  const offered = AppUpdate(
    version: '9.9.9',
    build: 99,
    apkUrl: 'https://example.test/a.apk',
    notesUrl: 'https://example.test/n',
    sizeBytes: 1,
    sha256: 'abc',
  );

  ({UpdateUi ui, int Function() calls}) flow({AppUpdate? found}) {
    var calls = 0;
    final ui = UpdateUi(
      check: () async {
        calls++;
        return found;
      },
      fetch: (_, __) async => null,
      install: (_) async => false,
    );
    return (ui: ui, calls: () => calls);
  }

  testWidgets('off means the check never runs', (tester) async {
    final f = flow(found: offered);
    await tester.pumpWidget(host(
      UpdateBar(skin: kSkinAbyss, ui: f.ui, enabled: false),
    ));
    await tester.pumpAndSettle();

    expect(f.calls(), 0);
    expect(find.byType(UpdateBar), findsOneWidget);
  });

  testWidgets('on means it asks once, after the first frame', (tester) async {
    final f = flow(found: null);
    await tester.pumpWidget(host(UpdateBar(skin: kSkinAbyss, ui: f.ui)));
    await tester.pumpAndSettle();

    expect(f.calls(), 1);
  });

  testWidgets('an offer the flow found is drawn, switch or no switch',
      (tester) async {
    final f = flow(found: null);
    await tester.pumpWidget(host(
      UpdateBar(skin: kSkinAbyss, ui: f.ui, enabled: false),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('9.9.9'), findsNothing);

    // A manual check runs through the same flow; the bar is a view of it.
    f.ui.open(known: offered);
    await tester.pump();

    expect(find.textContaining('9.9.9'), findsOneWidget);
  });

  testWidgets('withdrawing the offer takes the row away again', (tester) async {
    final f = flow(found: null);
    await tester.pumpWidget(host(
      UpdateBar(skin: kSkinAbyss, ui: f.ui, enabled: false),
    ));
    f.ui.open(known: offered);
    await tester.pump();
    expect(find.textContaining('9.9.9'), findsOneWidget);

    // A check that finds nothing is how an offer is withdrawn.
    await f.ui.checkNow();
    await tester.pump();

    expect(find.textContaining('9.9.9'), findsNothing, reason: 'a withdrawal withdraws');
  });

  testWidgets('the bar and the sheet cannot disagree', (tester) async {
    final f = flow(found: offered);
    await tester.pumpWidget(host(UpdateBar(skin: kSkinAbyss, ui: f.ui)));
    await tester.pumpAndSettle();

    expect(find.textContaining('9.9.9'), findsOneWidget);
    expect(f.ui.release?.version, '9.9.9',
        reason: 'one object answers both, so there is nothing to disagree about');
  });
}
