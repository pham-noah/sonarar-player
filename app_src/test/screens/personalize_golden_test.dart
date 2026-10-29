import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/screens/personalize_screen.dart';
import 'package:sonarar/theme/personalization.dart';

/// Renders the screen at phone size and writes a PNG, so the layout can be
/// looked at instead of only asserted on. Run with --update-goldens to refresh.
void main() {
  testWidgets('PERSONALIZE at phone size', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final root = Directory.systemTemp.createTempSync('sonarar-shot');
    final bg = Directory('${root.path}${Platform.pathSeparator}backgrounds')..createSync(recursive: true);
    final source = File('/mnt/c/Users/Noah/Documents/sonarar-player/test-fixtures/backdrop.jpg');
    if (source.existsSync()) {
      source.copySync('${bg.path}${Platform.pathSeparator}shot.jpg');
    }

    final state = AppState()
      ..libraryRoot = root.path
      ..setPersonalization(Personalization(
        backdrop: const BackdropSpec(
          file: 'shot.jpg',
          focusX: 0.5,
          focusY: 0.4,
          blur: 4,
          dim: 0.4,
          scale: 1.1,
          rotationDeg: -3,
        ),
        accent: const AccentSpec(source: AccentSource.manual, value: 0xFFD2455B),
        home: HomeLayout.defaults.toggle(HomeSection.rediscover),
      ));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: false),
      home: PersonalizeScreen(state: state, onSaveTheme: (_) {}),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(PersonalizeScreen),
      matchesGoldenFile('goldens/personalize.png'),
    );
  });
}
