
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/core/prefs.dart';
import 'package:sonarar/screens/settings_screen.dart';

/// The music folder is a setting now. Two things have to hold: it is reachable
/// from Settings, and a folder cannot be chosen unless it is actually a library.
void main() {
  testWidgets('Settings shows the folder and opens the picker', (tester) async {
    var opened = 0;
    final state = AppState();
    tester.view.physicalSize = const Size(400, 1400) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: SettingsScreen(
          state: state,
          showTitle: false,
          section: SettingsSection.behaviour,
          prefs: AppPrefs.initial,
          onPrefsChanged: (_) {},
          musicRoot: '/storage/emulated/0/Music/Sonarar',
          onOpenMusicFolder: () => opened++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The folder lives on the LIBRARY page.
    await tester.tap(find.text('LIBRARY'));
    await tester.pumpAndSettle();

    expect(find.text('LIBRARY'), findsWidgets);
    expect(find.text('MUSIC FOLDER'), findsOneWidget);
    expect(find.text('/storage/emulated/0/Music/Sonarar'), findsOneWidget);

    await tester.tap(find.text('MUSIC FOLDER'));
    await tester.pumpAndSettle();
    expect(opened, 1, reason: 'the row is the door to the folder picker');
  });

}
