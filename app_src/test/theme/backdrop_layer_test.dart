import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/backdrop_layer.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';

/// The backdrop has to actually put the picture on screen — not fall back to
/// the skin's flat colour because the file or the decode failed.
void main() {
  testWidgets('the photo reaches the screen, framed by its focus point', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = File('test-fixtures/backdrop.jpg');
    expect(fixture.existsSync(), isTrue, reason: 'fixture missing — the test would pass vacuously');

    final root = Directory.systemTemp.createTempSync('sonarar-backdrop');
    final dir = Directory('${root.path}${Platform.pathSeparator}backgrounds')..createSync(recursive: true);
    fixture.copySync('${dir.path}${Platform.pathSeparator}shot.jpg');

    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: PersonalBackdrop(
          root: root,
          spec: const BackdropSpec(file: 'shot.jpg', dim: 0, tint: false),
          skin: kSkinAbyss,
        ),
      ),
    ));

    // Decode before the frame is captured. A wall-clock delay made this pass
    // alone and fail in the full suite, where the isolate is busier.
    await tester.runAsync(() async {
      await precacheImage(FileImage(fixture), tester.element(find.byType(PersonalBackdrop)));
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PersonalBackdrop),
      matchesGoldenFile('goldens/backdrop_photo.png'),
    );
  });

  testWidgets('a missing file draws nothing rather than an empty box', (tester) async {
    final root = Directory.systemTemp.createTempSync('sonarar-backdrop-miss');
    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 200,
        height: 200,
        child: PersonalBackdrop(
          root: root,
          spec: const BackdropSpec(file: 'nope.jpg'),
          skin: kSkinAbyss,
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('rotation pads the frame so the corners stay covered', (tester) async {
    expect(PersonalBackdrop.rotationPadding(0), closeTo(1.0, 1e-9));
    expect(PersonalBackdrop.rotationPadding(45), closeTo(1.5, 1e-9));
    expect(PersonalBackdrop.rotationPadding(-45), closeTo(1.5, 1e-9));
    // Never smaller than the frame it has to cover.
    for (var deg = -180; deg <= 180; deg += 15) {
      expect(PersonalBackdrop.rotationPadding(deg.toDouble()), greaterThanOrEqualTo(1.0));
    }
  });
}
