library;

// The library header is the densest row of controls in the app: three sort
// chips and a view toggle on one line at the top of the list, above everything
// you came to tap. All four were under Android's 48 dp floor — the chips were
// 27 dp of ink with nothing around them, and the toggle was a bare 24 dp glyph
// with no semantics at all, so it was both the smallest and the only unnamed
// control on the screen.
//
// The a11y probe did not catch the unnamed one, and that is the reason this
// file exists as well as that fix: the probe built the screen with
// `onPlaylistGrid: null`, which draws the toggle dead and therefore without a
// tap node to complain about. A fixture that passes null for a callback is a
// fixture testing the absence of the control.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/l10n/app_localizations.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/theme/skin.dart';

const _floor = 48.0;

final _skin = skinFor(SkinId.amber);

final _tracks = <Track>[
  Track(
    id: 'a',
    title: 'A',
    artist: 'X',
    album: 'Y',
    duration: const Duration(minutes: 3),
    file: 'a.opus',
    cover: '',
    gainDb: -3.0,
  ),
];

class _Harness {
  _Harness({required this.onGrid, this.grid = false});

  final ValueChanged<bool>? onGrid;
  final bool grid;
  final sorts = <String>[];
}

Future<_Harness> _open(
  WidgetTester tester, {
  bool grid = false,
  bool live = true,
  Locale? locale,
}) async {
  tester.view.physicalSize = const Size(320, 640) * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final log = <String>[];
  final harness = _Harness(onGrid: live ? (_) {} : null, grid: grid);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Material(
        child: LibraryScreen(
          view: LibraryScreenView(
            tracks: _tracks,
            coverPathFor: (_) => null,
            skin: _skin,
            libraryRoot: '/music',
            likedIds: const {'a'},
            playlistSort: 'recents',
            playlistGrid: grid,
            onPlaylistSort: log.add,
            onPlaylistGrid: harness.onGrid,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return harness;
}

void main() {
  testWidgets('every sort chip offers 48 dp of target, not 27 of ink', (
    tester,
  ) async {
    await _open(tester);

    final chips = find.ancestor(
      of: find.text('RECENTS'),
      matching: find.byType(GestureDetector),
    );
    expect(chips, findsOneWidget, reason: 'the RECENTS sort chip is gone');

    final box = tester.getSize(chips);
    expect(
      box.height,
      greaterThanOrEqualTo(_floor),
      reason:
          'The sort chips are ${box.height} dp tall. They are the three '
          'most-tapped controls on the Library screen and were the smallest '
          'things on it; three chips and a thumb is a miss waiting to happen.',
    );
  });

  testWidgets('the view toggle is 48 dp square and says what it toggles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, grid: false, live: true, locale: const Locale('fi'));

    final toggle = find.bySemanticsLabel('Soittolistat ruudukossa');
    expect(
      toggle,
      findsOneWidget,
      reason:
          'The button that switches playlists between a list and a grid has '
          'no accessible name: it is a 24 dp glyph and nothing else, so it is '
          'unreachable and unidentifiable without sight.',
    );

    final size = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.grid_view_rounded),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(size.width, greaterThanOrEqualTo(_floor));
    expect(
      size.height,
      greaterThanOrEqualTo(_floor),
      reason:
          'The view toggle is ${size.height} dp tall — the smallest target '
          'in the header and the only way to change how playlists are drawn.',
    );

    final node = tester.getSemantics(toggle);
    expect(
      node.getSemanticsData().label,
      'Soittolistat ruudukossa',
      reason: 'the label is an English literal, not the locale in force',
    );
    expect(
      node.getSemanticsData().flagsCollection.isToggled == Tristate.isFalse,
      isTrue,
      reason:
          'a toggle that never reports its state is a button that happens '
          'to look pressed',
    );
    handle.dispose();
  });

  testWidgets('pressing the toggle asks for the other view, once', (
    tester,
  ) async {
    final calls = <bool>[];
    tester.view.physicalSize = const Size(320, 640) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: LibraryScreen(
            view: LibraryScreenView(
              tracks: _tracks,
              coverPathFor: (_) => null,
              skin: _skin,
              libraryRoot: '/music',
              likedIds: const {'a'},
              playlistSort: 'recents',
              playlistGrid: true,
              onPlaylistSort: (_) {},
              onPlaylistGrid: calls.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pump();
    expect(
      calls,
      [false],
      reason:
          'the toggle is drawn as "list" while the grid is on, so pressing '
          'it has to ask for the list — not the list it is already showing',
    );

    final ticks = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') ticks.add('tick');
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pump();
    expect(
      ticks,
      ['tick'],
      reason:
          'every other icon-only control in the app ticks; this one used to '
          'change the layout under the thumb with no feedback at all',
    );
  });

  testWidgets('a dead header says nothing rather than lying', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = await _open(tester, live: false);

    expect(harness.onGrid, isNull);
    final node = tester.getSemantics(find.byIcon(Icons.grid_view_rounded));
    expect(
      node.getSemanticsData().flagsCollection.isEnabled == Tristate.isFalse,
      isTrue,
      reason:
          'with no callback the toggle is drawn dimmed, so it has to '
          'announce itself as disabled rather than as a button that does '
          'nothing when pressed',
    );
    handle.dispose();
  });
}
