library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/playlists.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/theme/skin_policy.dart';

Track _t(String id) => Track(
      id: id,
      title: 'Title $id',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(minutes: 3),
      file: '$id.opus',
      cover: '',
      gainDb: null);

List<Track> _library(int n) => [for (var i = 0; i < n; i++) _t('t$i')];

AppState _afternoonOnly() {
  final state = AppState();
  state.attachLibrary([for (var i = 0; i < 6; i++) _t('t$i')]);
  state.setPlaylists(PlaylistList([
    Playlist(id: 'v_afternoon', name: 'Afternoon', trackIds: const ['t0', 't1']),
  ]));
  return state;
}

void main() {
  group('keep playing when the queue ends', () {
    test('it DOES refill when the context has a list for the moment', () {
      final state = _afternoonOnly();
      state.updateContext(const PlayContext(
          band: ContextBand.afternoon, sky: Sky.unknown, localHour: 14));
      state.setQueueForTest([_t('t5')]);
      expect(state.refillFromContext(), isTrue,
          reason: 'the afternoon list is right there and the refill still refused');
    });

    test('AND AT NIGHT IT STILL KEEPS PLAYING — the bug he reported', () {
      final state = _afternoonOnly();
      state.updateContext(const PlayContext(
          band: ContextBand.night, sky: Sky.unknown, localHour: 23));
      state.setQueueForTest([_t('t5')]);

      // ignore: avoid_print
      print('night mix = ${state.dynamicMix()?.trackIds}');
      expect(state.dynamicMix(), isNull,
          reason: 'fixture no longer reproduces the bug — night should have no list');
      expect(state.refillFromContext(), isTrue,
          reason: '"keep playing when the queue ends" went silent at night');
      expect(state.queue!.current!.id, isNot('t5'),
          reason: 'the refill left the ended track current, so it would replay');
    });

    test('the MIX itself is untouched — only the refill falls back', () {
      final state = _afternoonOnly();
      state.updateContext(const PlayContext(
          band: ContextBand.night, sky: Sky.unknown, localHour: 23));
      expect(state.dynamicMix(), isNull,
          reason: 'the fallback leaked into dynamic MODE — that rule is his and stays');

      state.setQueueForTest([_t('t5')]);
      expect(state.refillFromContext(allowLibraryFallback: false), isFalse);
    });
  });

  group('the queue reorders by the PANEL\'s indices, not the queue\'s', () {
    AppState queued() {
      final s = AppState()..attachLibrary(_library(6));
      s.setQueueForTest(_library(6));

      s.playTrackNow('t2');
      return s;
    }

    test('the fixture really is offset — upNext does not start at queue index 0', () {
      final s = queued();
      expect(s.played.length, 2, reason: 'fixture is wrong: nothing has played');
      expect(s.upNext.first.id, 't3');

      expect(s.queue!.order.first.id, 't0');
      expect(s.queue!.index, 2);
    });

    test('moving the panel\'s first row reorders THAT row, not queue index 0', () {
      final s = queued();
      final before = s.upNext.map((t) => t.id).toList();
      expect(before, ['t3', 't4', 't5']);

      final ok = s.moveInUpcoming(0, 1);
      expect(ok, isTrue);

      final after = s.upNext.map((t) => t.id).toList();
      expect(after, ['t4', 't3', 't5'],
          reason: 'the wrong row moved — the panel indices were used as queue indices');

      expect(s.played.map((t) => t.id).toList(), ['t0', 't1']);
      expect(s.queue!.current!.id, 't2',
          reason: 'the reorder changed what is playing');
    });

    test('an out-of-range panel index is refused rather than clamping into the past', () {
      final s = queued();
      expect(s.moveInUpcoming(99, 0), isFalse);
      expect(s.played.map((t) => t.id).toList(), ['t0', 't1'],
          reason: 'a bad index reached into the played part of the queue');
    });
  });

  group('the badge is a readout when OFFLINE is on', () {
    Future<void> pump(WidgetTester tester, {required bool contextOn}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final state = AppState();
      state.attachLibrary([_t('a')]);
      state.applyQueuePrefs(
          defaultMode: true, refill: false, contextEnabled: contextOn);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PlayerScreen(state: state, track: _t('a')),
        ),
      ));
      await tester.pump();
    }

    GestureDetector? badgeTap(WidgetTester tester) {
      final badge = find.byKey(PlayerScreen.contextBadgeKey);
      expect(badge, findsOneWidget, reason: 'the context badge is not on the screen');
      final gds = tester
          .widgetList<GestureDetector>(find.descendant(
            of: badge,
            matching: find.byType(GestureDetector),
          ))
          .toList();
      return gds.isEmpty ? null : gds.first;
    }

    testWidgets('ON: the badge toggles the mode', (tester) async {
      await pump(tester, contextOn: true);
      final gd = badgeTap(tester);
      expect(gd, isNotNull,
          reason: 'the badge lost its tap entirely — it should still toggle while online');
      expect(gd!.onTap, isNotNull);
    });

    testWidgets('OFF: the badge has NO tap, so it cannot switch to dynamic',
        (tester) async {
      await pump(tester, contextOn: false);
      final gd = badgeTap(tester);

      expect(gd?.onTap, isNull,
          reason: 'pressing the badge still switches the mode with OFFLINE on');
    });
  });
}
