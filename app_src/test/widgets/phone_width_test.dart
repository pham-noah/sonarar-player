@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/bonds_screen.dart';
import 'package:sonarar/library/compendium.dart';
import 'package:sonarar/screens/compendium_screen.dart';
import 'package:sonarar/screens/history_screen.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/rules_editor_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';
import 'package:sonarar/screens/tab_bar_view.dart';
import 'package:sonarar/screens/track_panel.dart';
import 'package:sonarar/screens/archive_screen.dart';
import 'package:sonarar/theme/skin.dart';

const List<Size> kPhoneSizes = [
  Size(360, 780),
  Size(393, 852),
  Size(412, 915),
];

List<Track> _tracks(int n) => [
      for (var i = 0; i < n; i++)
        Track(
          id: 't$i',

          title: 'A fairly long track title number $i that has to ellipsise',
          artist: 'ATLUS Sound Team feat. Someone With A Long Name',
          album: 'Persona 5 Royal Original Soundtrack',
          duration: const Duration(minutes: 4, seconds: 32),
          file: 't$i.m4a',
          cover: '',
          gainDb: 0,
        ),
    ];

Future<String?> _overflowAt(
  WidgetTester tester,
  Size size,
  Widget Function() child,
) async {
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: Material(child: child())));
  await tester.pump();

  final ex = tester.takeException();
  if (ex == null) return null;
  final text = ex.toString();
  if (text.contains('overflowed')) return text.split('\n').first;

  return 'OTHER: ${text.split('\n').first}';
}

void main() {
  group('player survives every phone width AND height', () {
    for (final size in kPhoneSizes) {
      testWidgets('player @ ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => PlayerScreen(
            state: AppState(),
            track: _tracks(1).first,
            volume: 0.65,
            onVolume: (_) {},
            onPlayPause: () {},
            onCycleRepeat: () {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('library survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('library @ ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => LibraryScreen(
            tracks: _tracks(12),
            coverPathFor: (_) => null,
            skin: kSkinCrimson,
            likedIds: const {'t1'},
            onManage: (_) {},
            onQueue: (_) => SwipeOutcome.queued,
            onLike: (_) => SwipeOutcome.liked,
            onPlay: (_) {},
            onTogglePlay: (_) {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('settings survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('settings @ ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        final msg = await _overflowAt(
          tester,
          size,

          () => SettingsScreen(
            state: AppState(),
            onContextsChanged: () {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('velvet room survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('velvet room @ ${size.width.toInt()}', (tester) async {
        final state = AppState()..attachLibrary(_tracks(12));
        final msg = await _overflowAt(
          tester,
          size,
          () => ArchiveScreen(
            state: state,
            onOpenTagEditor: (_) {},
            onOpenBonds: () {},
            onRevertAllTags: () {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('bonds survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('bonds @ ${size.width.toInt()}', (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => BondsScreen(
            state: AppState(),
            events: const [],
            tracks: _tracks(6),
            onReset: () {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('rules editor survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('rules @ ${size.width.toInt()}', (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => RulesEditorScreen(state: AppState(), onChanged: () {}),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('the tab bar fits every phone width', () {
    for (final size in kPhoneSizes) {
      for (final tab in AppTab.values) {
        testWidgets('tab bar @ ${size.width.toInt()} — ${tab.name}',
            (tester) async {
          final msg = await _overflowAt(
            tester,
            size,
            () => TabBarView2(skin: kSkinCrimson, current: tab, onSelect: (_) {}),
          );
          expect(msg, isNull, reason: msg ?? '');
        });
      }
    }
  });

  group('the search tab survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('search @ ${size.width.toInt()}', (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => LibraryScreen(
            searchOnly: true,
            tracks: _tracks(12),
            coverPathFor: (_) => null,
            skin: kSkinCrimson,
            likedIds: const {'t1'},
            onManage: (_) {},
            onQueue: (_) => SwipeOutcome.queued,
            onLike: (_) => SwipeOutcome.liked,
            onPlay: (_) {},
            onTogglePlay: (_) {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('the track panel survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('track panel @ ${size.width.toInt()}', (tester) async {
        final state = AppState()..attachLibrary(_tracks(4));
        final msg = await _overflowAt(
          tester,
          size,
          () => TrackPanel(
            state: state,
            track: _tracks(1).first,
            position: const Duration(seconds: 42),
            onToggleBookmark: () {},
            onFixTags: () {},
            onLoopPoints: () {},
            onAddToPlaylist: () {},
            onNeverInShuffle: () {},
            playCount: 7,
            completionCount: 5,
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('history survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('history @ ${size.width.toInt()}', (tester) async {
        final msg = await _overflowAt(
          tester,
          size,
          () => HistoryScreen(
            skin: kSkinCrimson,
            events: const [],
            tracks: _tracks(6),
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('the compendium survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('compendium @ ${size.width.toInt()}', (tester) async {
        final entries = buildCompendium(tracks: _tracks(12), events: const [])
            .entries;
        final msg = await _overflowAt(
          tester,
          size,
          () => CompendiumScreen(skin: kSkinCrimson, entries: entries),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });

  group('the archive survives every phone width', () {
    for (final size in kPhoneSizes) {
      testWidgets('velvet room @ ${size.width.toInt()}', (tester) async {
        final state = AppState()..attachLibrary(_tracks(12));
        final msg = await _overflowAt(
          tester,
          size,
          () => ArchiveScreen(
            state: state,
            compendiumEntries: null,
            onOpenBonds: () {},
            onOpenRules: () {},
            onOpenExclusions: () {},
            onRevertAllTags: () {},
          ),
        );
        expect(msg, isNull, reason: msg ?? '');
      });
    }
  });
}
