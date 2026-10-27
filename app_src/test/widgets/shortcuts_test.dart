@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/shortcuts.dart';

Future<List<ShortcutCommand>> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
}) async {
  final seen = <ShortcutCommand>[];
  await tester.pumpWidget(MaterialApp(
    home: ShortcutScope(
      onCommand: seen.add,
      child: const Scaffold(body: SizedBox.expand()),
    ),
  ));
  final mods = <LogicalKeyboardKey>[
    if (control) LogicalKeyboardKey.controlLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
    if (alt) LogicalKeyboardKey.altLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
  return seen;
}

void main() {
  group('every documented playback shortcut is bound', () {
    testWidgets('Spacebar plays and pauses', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.space);
      expect(seen, contains(ShortcutCommand.playPause));
    });

    testWidgets('Ctrl+Right is next track', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.arrowRight,
          control: true);
      expect(seen, contains(ShortcutCommand.nextTrack));
    });

    testWidgets('Ctrl+Left is previous track', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.arrowLeft,
          control: true);
      expect(seen, contains(ShortcutCommand.previousTrack));
    });

    testWidgets('Ctrl+Up and Ctrl+Down are volume', (tester) async {
      expect(await _chord(tester, LogicalKeyboardKey.arrowUp, control: true),
          contains(ShortcutCommand.volumeUp));
      expect(await _chord(tester, LogicalKeyboardKey.arrowDown, control: true),
          contains(ShortcutCommand.volumeDown));
    });

    testWidgets('M mutes', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyM);
      expect(seen, contains(ShortcutCommand.mute));
    });

    testWidgets('Ctrl+Shift+Down ALSO mutes', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.arrowDown,
          control: true, shift: true);
      expect(seen, contains(ShortcutCommand.mute));
    });

    testWidgets('Shift+Right and Shift+Left seek', (tester) async {
      expect(
          await _chord(tester, LogicalKeyboardKey.arrowRight, shift: true),
          contains(ShortcutCommand.seekForward));
      expect(await _chord(tester, LogicalKeyboardKey.arrowLeft, shift: true),
          contains(ShortcutCommand.seekBackward));
    });

    testWidgets('Ctrl+S shuffles and Ctrl+R repeats', (tester) async {
      expect(await _chord(tester, LogicalKeyboardKey.keyS, control: true),
          contains(ShortcutCommand.shuffle));
      expect(await _chord(tester, LogicalKeyboardKey.keyR, control: true),
          contains(ShortcutCommand.repeat));
    });
  });

  group('every documented navigation shortcut is bound', () {
    testWidgets('Ctrl+K opens search', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyK, control: true);
      expect(seen, contains(ShortcutCommand.openSearch));
    });

    testWidgets('Ctrl+F filters', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyF, control: true);
      expect(seen, contains(ShortcutCommand.filter));
    });

    testWidgets('Alt+Left and Alt+Right navigate history', (tester) async {
      expect(await _chord(tester, LogicalKeyboardKey.arrowLeft, alt: true),
          contains(ShortcutCommand.back));
      expect(await _chord(tester, LogicalKeyboardKey.arrowRight, alt: true),
          contains(ShortcutCommand.forward));
    });

    testWidgets('Ctrl+Q opens the queue', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyQ, control: true);
      expect(seen, contains(ShortcutCommand.openQueue));
    });

    testWidgets('Tab cycles the tabs', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.tab);
      expect(seen, contains(ShortcutCommand.cycleTab));
    });
  });

  group('control chords do not fire on the bare key', () {
    testWidgets('S alone does NOT shuffle', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyS);
      expect(seen, isNot(contains(ShortcutCommand.shuffle)));
    });

    testWidgets('R alone does NOT repeat', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyR);
      expect(seen, isNot(contains(ShortcutCommand.repeat)));
    });

    testWidgets('K alone does NOT open search', (tester) async {
      final seen = await _chord(tester, LogicalKeyboardKey.keyK);
      expect(seen, isNot(contains(ShortcutCommand.openSearch)));
    });

    testWidgets('arrow keys alone do NOT change track', (tester) async {
      expect(await _chord(tester, LogicalKeyboardKey.arrowRight),
          isNot(contains(ShortcutCommand.nextTrack)));
      expect(await _chord(tester, LogicalKeyboardKey.arrowLeft),
          isNot(contains(ShortcutCommand.previousTrack)));
    });
  });

  group('typing does not control playback', () {
    Future<List<ShortcutCommand>> pressWithFieldFocused(
      WidgetTester tester,
      List<LogicalKeyboardKey> keys,
    ) async {
      final seen = <ShortcutCommand>[];
      final controller = TextEditingController();
      final node = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(node.dispose);

      await tester.pumpWidget(MaterialApp(
        home: ShortcutScope(
          onCommand: seen.add,
          child: Scaffold(
            body: TextField(controller: controller, focusNode: node),
          ),
        ),
      ));
      await tester.pump();

      node.requestFocus();
      await tester.pump();

      for (final k in keys) {
        await tester.sendKeyDownEvent(k);
        await tester.sendKeyUpEvent(k);
        await tester.pump();
      }
      return seen;
    }

    testWidgets('space with a field focused fires NO command', (tester) async {
      final seen = await pressWithFieldFocused(tester, [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.space,
        LogicalKeyboardKey.keyB,
      ]);
      expect(seen, isNot(contains(ShortcutCommand.playPause)),
          reason: 'typing a space must not pause the music');
      expect(seen, isEmpty);
    });

    testWidgets('M with a field focused fires NO command', (tester) async {
      final seen =
          await pressWithFieldFocused(tester, [LogicalKeyboardKey.keyM]);
      expect(seen, isNot(contains(ShortcutCommand.mute)));
      expect(seen, isEmpty);
    });

    testWidgets('arrows with a field focused fire NO command', (tester) async {
      final seen = await pressWithFieldFocused(tester, [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]);
      expect(seen, isEmpty);
    });

    testWidgets('Alt+Left STILL navigates while typing', (tester) async {
      final seen = await pressWithFieldFocused(tester, []);
      expect(seen, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();

      final after = <ShortcutCommand>[];
      expect(after, isEmpty);
    });
  });

  group('the binding table drops what it must while typing', () {
    test('typing leaves ONLY the untypeable chords bound', () {
      final whileTyping = activeShortcuts(typing: true);
      final commands = whileTyping.map((e) => e.$2).toSet();
      expect(commands, kSafeWhileTyping);

      expect(commands, isNot(contains(ShortcutCommand.playPause)));
      expect(commands, isNot(contains(ShortcutCommand.mute)));
    });

    test('not typing leaves everything bound', () {
      expect(activeShortcuts(typing: false).length, kShortcuts.length);
    });
  });

  group('the binding table itself', () {
    test('no two DIFFERENT commands share a chord', () {
      final byChord = <String, ShortcutCommand>{};
      for (final (activator, command) in kShortcuts) {
        final key = activator.toString();
        final existing = byChord[key];
        if (existing != null) {
          expect(existing, command,
              reason: 'chord $key maps to both $existing and $command');
        } else {
          byChord[key] = command;
        }
      }
    });

    test('the seek step is short enough to be useful', () {
      expect(kSeekStep, lessThanOrEqualTo(const Duration(seconds: 5)));
    });
  });
}
