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
    testWidgets('the downloader opens from the Library header — ${id.name}',
        (tester) async {
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

      // The downloader is a page the Library opens, not a tab: a tab that
      // needs the network and a 14 MB engine cannot promise anything.
      await tester.tap(find.text('LIBRARY'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }

      final findMusic = find.byIcon(Icons.download_rounded);
      expect(findMusic, findsOneWidget,
          reason: 'no way to the downloader from the library header');
      await tester.tap(findMusic);
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
