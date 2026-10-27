library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/widgets/mini_player_host.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Beneath the Mask',
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );

void main() {
  group('the clearance is the bars, added up', () {
    test('Persona reserves the bar plus the mini player, with no inset', () {
      final clearance = ScreenLayout.persona.bottomClearance;

      expect(clearance, LayoutSpec.tabBarHeight + LayoutSpec.miniPlayerHeight,
          reason: 'Persona\'s bar is docked with zero bottom inset, so the '
              'clearance is exactly the two bars');
      expect(clearance, greaterThan(120),
          reason: 'this must not fall back below what the library used to '
              'reserve — that was already too little for the search tab');
    });

    test('the plain layouts add the floating bar\'s own bottom inset', () {
      final clearance = ScreenLayout.plain.bottomClearance;

      expect(clearance,
          ScreenLayout.persona.bottomClearance + ScreenLayout.plain.tabBarInsets.bottom,
          reason: 'the floating bar carries a bottom inset Persona does not, so '
              'the room has to grow by exactly that much');
      expect(clearance, greaterThan(ScreenLayout.persona.bottomClearance));
    });

    test('the mini player\'s constant is the measured widget height', () {
      expect(LayoutSpec.miniPlayerHeight, 64.0);
    });
  });

  group('the constant still matches the widget', () {
    testWidgets('the rendered mini player is exactly the reserved height',
        (tester) async {
      tester.view.physicalSize = const Size(420, 860) * 3;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState()..attachLibrary([_t('a')]);
      state.playTrack(state.library.first);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: MiniPlayerHost(
              skin: kSkinCrimson,
              state: state,
              duration: ValueNotifier<Duration>(Duration.zero),
              playing: false,
              cover: null,
              onSeek: (_) {},
              onPlayPause: () {},
              onCycleRepeat: () {},
              onToggleLyrics: () {},
              onOpenQueue: () {},
              onSwipeNext: () {},
              onSwipePrevious: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      final height = tester.getSize(find.byType(MiniPlayer)).height;
      expect(height, LayoutSpec.miniPlayerHeight,
          reason: 'the mini player renders at $height, but the bottom clearance '
              'reserves ${LayoutSpec.miniPlayerHeight} — the bar and the '
              'constant have drifted');
    });
  });
}
