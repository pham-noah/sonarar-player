import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_focus.dart';
import 'package:sonarar/art/art_spec.dart';
import 'package:sonarar/screens/art_editor_screen.dart';
import 'package:sonarar/theme/skin.dart';

/// The editor must save what it shows, and show what the player will draw.
void main() {
  late Directory bundle;
  late List<ArtSpec?> popped;

  setUp(() {
    bundle = Directory.systemTemp.createTempSync('sonarar-editor');
    popped = [];
  });
  tearDown(() => bundle.deleteSync(recursive: true));

  /// The editor returns its spec through the route; save is the caller's job.
  Widget host(ArtSpec initial) => MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  popped.add(await Navigator.of(context).push<ArtSpec>(
                    MaterialPageRoute(
                      builder: (_) => ArtEditorScreen(
                        skin: skinFor(SkinId.abyss),
                        assetPath: 'assets/brand/logo_mark.png',
                        aspect: 1,
                        focus: ArtFocus.centre,
                        initial: initial,
                      ),
                    ),
                  ));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  testWidgets('dragging the picture moves it', (tester) async {
    await tester.pumpWidget(host(ArtSpec.none));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GestureDetector).first, const Offset(120, 120));
    await tester.pump();

    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    final saved = popped.single;
    expect(saved, isNotNull);
    expect(saved!.dx, greaterThan(0), reason: 'a rightward drag did not move it');
    expect(saved.dy, greaterThan(0));
  });

  testWidgets('SAVE hands the spec back untouched when nothing changed', (tester) async {
    await tester.pumpWidget(host(ArtSpec.none));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    expect(popped.single?.isDefault, isTrue);
  });

  testWidgets('an existing spec is shown, and RESET clears it', (tester) async {
    await tester.pumpWidget(host(const ArtSpec(zoom: 1.8, rotationDeg: 6)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('1.8x'), findsOneWidget);
    expect(find.text('6°'), findsOneWidget);

    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    expect(popped.single?.isDefault, isTrue);
  });
}
