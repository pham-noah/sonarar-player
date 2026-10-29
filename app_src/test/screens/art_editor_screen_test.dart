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

  setUp(() => bundle = Directory.systemTemp.createTempSync('sonarar-editor'));
  tearDown(() => bundle.deleteSync(recursive: true));

  Widget host(ArtSpec initial, {ValueChanged<ArtSpec>? onSave}) => MaterialApp(
        home: ArtEditorScreen(
          skin: skinFor(SkinId.abyss),
          bundle: bundle,
          assetPath: 'assets/brand/logo_mark.png',
          aspect: 1,
          focus: ArtFocus.centre,
          initial: initial,
          onSave: onSave,
        ),
      );

  testWidgets('dragging the picture moves it', (tester) async {
    await tester.pumpWidget(host(ArtSpec.none));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GestureDetector).first, const Offset(120, 120));
    await tester.pump();

    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    final saved = ArtSpec.read(bundle);
    expect(saved.dx, greaterThan(0), reason: 'a rightward drag did not move it');
    expect(saved.dy, greaterThan(0));
  });

  testWidgets('SAVE writes the spec beside the picture', (tester) async {
    late ArtSpec saved;
    await tester.pumpWidget(host(ArtSpec.none, onSave: (s) => saved = s));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    expect(saved.isDefault, isTrue);
    expect(ArtSpec.fileFor(bundle).existsSync(), isFalse,
        reason: 'an untouched picture should not leave a spec file');
  });

  testWidgets('an existing spec is shown, and RESET clears it', (tester) async {
    await tester.pumpWidget(host(const ArtSpec(zoom: 1.8, rotationDeg: 6)));
    await tester.pumpAndSettle();

    expect(find.text('RESET'), findsOneWidget);
    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('art-save')));
    await tester.pumpAndSettle();

    expect(ArtSpec.read(bundle).isDefault, isTrue);
  });
}
