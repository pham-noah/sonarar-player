library;

// Every node the semantics tree exposes with a tap action must carry a label,
// or TalkBack announces "button" and nothing else. This walks the tree the
// screen reader actually receives, so it measures the announcement rather than
// the intent: a control whose label lives in a sibling `Text` reads as bare.
//
// Each failure names its size and the nearest labelled ancestor, which is
// enough to find the control in `lib/` without a widget-tree dump.

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/player/queue.dart';
import 'package:sonarar/screens/library_screen.dart';
import 'package:sonarar/screens/mini_player.dart';
import 'package:sonarar/screens/player_screen.dart';
import 'package:sonarar/screens/queue_screen.dart';
import 'package:sonarar/screens/settings_screen.dart';

Track _t(String id, String title, String artist) => Track(
  id: id,
  title: title,
  artist: artist,
  album: 'Persona 3 Reload',
  duration: const Duration(seconds: 208),
  file: '$id.opus',
  cover: '',
  gainDb: -3.0,
);

final _lib = <Track>[
  _t('a', '全ての人の魂の戦い', 'ATLUS Sound Team'),
  _t('b', 'Living With Determination', 'ATLUS Sound Team'),
  _t('c', 'Burn My Dread', 'Lotus Juice'),
];

AppState _state() {
  final s = AppState()..attachLibrary(_lib);
  s.playTrackNow('a');
  return s;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, home: Scaffold(body: child)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Tappable nodes that announce as a bare "button".
///
/// A node is labelled when the announcement would carry a word: its own label,
/// its value, a tooltip, or — via merging — a child that has one. The parent
/// walk is what makes the report readable: "inside 'Queue'" points at a section,
/// "inside 'Play'" points at a control that lost its own name.
List<String> _unlabelledTappables(WidgetTester tester) {
  final owner = tester.binding.renderViews.first.owner!.semanticsOwner;
  if (owner == null) throw StateError('ensureSemantics() was not called');
  final out = <String>[];

  String? labelOf(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.label.trim().isNotEmpty) return data.label;
    if (data.value.trim().isNotEmpty) return data.value;
    String? child;
    node.visitChildren((c) {
      child ??= labelOf(c);
      return child == null;
    });
    return child;
  }

  String where(SemanticsNode node) {
    SemanticsNode? cursor = node.parent;
    while (cursor != null) {
      final l = cursor.getSemanticsData().label.trim();
      if (l.isNotEmpty) {
        return ' inside "${l.length > 24 ? l.substring(0, 24) : l}"';
      }
      cursor = cursor.parent;
    }
    return '';
  }

  void walk(SemanticsNode node) {
    final data = node.getSemanticsData();
    final tap = data.hasAction(SemanticsAction.tap);
    final long = data.hasAction(SemanticsAction.longPress);
    if ((tap || long) && (labelOf(node) ?? '').trim().isEmpty) {
      out.add(
        '${data.tooltip.isEmpty ? 'no tooltip' : 'tooltip'} '
        '${node.rect.width.round()}×${node.rect.height.round()}'
        '${tap ? ' tap' : ''}${long ? ' long-press' : ''}'
        '${where(node)}',
      );
    }
    node.visitChildren((child) {
      walk(child);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return out;
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 860) * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('the player announces every control it draws', (tester) async {
    phone(tester);
    // Owned by the test body: the framework asserts on a live handle at
    // teardown, which runs after this closure returns.
    final handle = tester.ensureSemantics();

    final s = _state();
    await _pump(
      tester,
      PlayerScreen(
        view: PlayerView(state: s, track: s.currentTrack, cover: null),
      ),
    );

    final bare = _unlabelledTappables(tester);
    handle.dispose();

    expect(
      bare,
      isEmpty,
      reason:
          'the player is the screen a screen-reader user reaches most '
          'often, and each of these announces as "button"',
    );
  });

  testWidgets('settings announces every control it draws', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();

    await _pump(tester, SettingsScreen(state: _state()));

    final bare = _unlabelledTappables(tester);
    handle.dispose();

    expect(
      bare,
      isEmpty,
      reason:
          'here a bare button is a setting nobody can identify, so it '
          'cannot be changed',
    );
  });

  testWidgets('the library announces every control it draws', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();

    final s = _state();
    await _pump(
      tester,
      LibraryScreen(
        view: LibraryScreenView(
          tracks: _lib,
          coverPathFor: (_) => null,
          skin: s.skin,
          libraryRoot: '/music',
          likedIds: {'a'},
          onPlaylistSort: (_) {},
          // Non-null on purpose. With both null the header drew a dead sort row
          // and no view toggle, so the probe had nothing to inspect and passed
          // while the toggle announced an unlabelled button.
          onPlaylistGrid: (_) {},
        ),
      ),
    );

    final bare = _unlabelledTappables(tester);
    handle.dispose();

    expect(bare, isEmpty);
  });

  testWidgets('the queue announces every control it draws', (tester) async {
    phone(tester);
    final handle = tester.ensureSemantics();

    final s = _state();
    await _pump(tester, QueuePanel(state: s));

    final bare = _unlabelledTappables(tester);
    handle.dispose();

    expect(
      bare,
      isEmpty,
      reason:
          'the queue is mostly rows you swipe; a row whose swipe targets '
          'are unnamed is a row that cannot be edited without sight',
    );
  });

  testWidgets('the mini player announces every control it draws', (
    tester,
  ) async {
    phone(tester);
    final handle = tester.ensureSemantics();

    final s = _state();
    await _pump(
      tester,
      MiniPlayer(
        skin: s.skin,
        track: s.currentTrack!,
        cover: null,
        playing: true,
        // A playing bar has a position, so the scrub has something to say and
        // the two ±5s actions exist: an unseekable bar would pass this probe
        // while the control it is testing sits inert.
        position: const Duration(seconds: 42),
        duration: const Duration(seconds: 208),
        onSeek: (_) {},
        onPlayPause: () {},
        onCycleRepeat: () {},
        repeatMode: RepeatMode.off,
        onOpen: () {},
        onDisband: () {},
      ),
    );

    final bare = _unlabelledTappables(tester);
    handle.dispose();

    expect(
      bare,
      isEmpty,
      reason:
          'the bar sits over every screen, so a bare button here is the '
          'one nobody can skip past',
    );
  });
}
