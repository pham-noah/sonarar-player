library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/skin_policy.dart';

import 'shell_probe.dart';

Track _t(String id) => Track(
      id: id, title: 'Title $id', artist: 'a', album: 'b',
      duration: const Duration(minutes: 3), file: '$id.opus', cover: '', gainDb: null);

void main() {
  for (final id in [SkinId.abyss, SkinId.minimal, SkinId.bloom]) {
    testWidgets('the SEARCH tab actually shows its field — ${id.name}', (tester) async {
      tester.view.physicalSize = const Size(420, 860) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.attachLibrary([for (var i = 0; i < 30; i++) _t('t$i')]);
      state.updateContext(const PlayContext(
          band: ContextBand.evening, whereabouts: Whereabouts.home,
          sky: Sky.unknown, localHour: 19));
      state.chooseSkinManually(id);

      await tester.pumpWidget(MaterialApp(home: HomeShell(state: state)));
      await tester.pump(const Duration(milliseconds: 50));
      HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      final searchTab = find.text('SEARCH');
      expect(searchTab, findsWidgets, reason: 'no SEARCH tab in the shell');
      await tester.tap(searchTab.first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      final field = find.byType(TextField);
      // ignore: avoid_print
      print('${id.name}: TextFields on the SEARCH tab = ${field.evaluate().length}');
      for (final e in field.evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        // ignore: avoid_print
        print('    rect = $r   visible=${r.top >= 0 && r.bottom <= 860}');
      }
      expect(field, findsWidgets, reason: 'the SEARCH tab has no TextField at all');
    });
  }
}
