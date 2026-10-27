library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ShortcutCommand {
  playPause,
  nextTrack,
  previousTrack,
  volumeUp,
  volumeDown,
  mute,
  seekForward,
  seekBackward,
  shuffle,
  repeat,
  openSearch,
  filter,
  back,
  forward,
  openQueue,
  cycleTab,
}

const Duration kSeekStep = Duration(seconds: 5);

const double kVolumeStep = 0.05;

const Set<ShortcutCommand> kSafeWhileTyping = {
  ShortcutCommand.back,
  ShortcutCommand.forward,
};

const List<(ShortcutActivator, ShortcutCommand)> kShortcuts = [

  (SingleActivator(LogicalKeyboardKey.space), ShortcutCommand.playPause),
  (
    SingleActivator(LogicalKeyboardKey.arrowRight, control: true),
    ShortcutCommand.nextTrack,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
    ShortcutCommand.previousTrack,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
    ShortcutCommand.volumeUp,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
    ShortcutCommand.volumeDown,
  ),
  (SingleActivator(LogicalKeyboardKey.keyM), ShortcutCommand.mute),
  (
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true, shift: true),
    ShortcutCommand.mute,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
    ShortcutCommand.seekForward,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
    ShortcutCommand.seekBackward,
  ),
  (
    SingleActivator(LogicalKeyboardKey.keyS, control: true),
    ShortcutCommand.shuffle,
  ),
  (
    SingleActivator(LogicalKeyboardKey.keyR, control: true),
    ShortcutCommand.repeat,
  ),

  (
    SingleActivator(LogicalKeyboardKey.keyK, control: true),
    ShortcutCommand.openSearch,
  ),
  (
    SingleActivator(LogicalKeyboardKey.keyF, control: true),
    ShortcutCommand.filter,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true),
    ShortcutCommand.back,
  ),
  (
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true),
    ShortcutCommand.forward,
  ),
  (
    SingleActivator(LogicalKeyboardKey.keyQ, control: true),
    ShortcutCommand.openQueue,
  ),
  (SingleActivator(LogicalKeyboardKey.tab), ShortcutCommand.cycleTab),
];

bool textFieldHasFocus() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;

  var inTextField = false;
  ctx.visitAncestorElements((el) {
    if (el.widget is EditableText) {
      inTextField = true;
      return false;
    }
    return true;
  });
  return inTextField;
}

List<(ShortcutActivator, ShortcutCommand)> activeShortcuts({
  required bool typing,
}) {
  if (!typing) return kShortcuts;
  return [
    for (final entry in kShortcuts)
      if (kSafeWhileTyping.contains(entry.$2)) entry,
  ];
}

class ShortcutScope extends StatefulWidget {
  const ShortcutScope({super.key, required this.onCommand, required this.child});

  final void Function(ShortcutCommand) onCommand;
  final Widget child;

  @override
  State<ShortcutScope> createState() => _ShortcutScopeState();
}

class _ShortcutScopeState extends State<ShortcutScope> {
  FocusNode? _fieldNode;
  bool get _typing => _fieldNode != null;

  @override
  void initState() {
    super.initState();

    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final node = FocusManager.instance.primaryFocus;

    final isField = node != null && _nodeIsInTextField(node);
    final next = isField ? node : null;
    if (next != _fieldNode) setState(() => _fieldNode = next);
  }

  static bool _nodeIsInTextField(FocusNode node) {
    final ctx = node.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;

    var inField = false;
    ctx.visitAncestorElements((el) {
      if (el.widget is EditableText) {
        inField = true;
        return false;
      }
      return true;
    });
    return inField;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final typing = _typing;
    for (final (activator, command) in kShortcuts) {
      if (!activator.accepts(event, HardwareKeyboard.instance)) continue;

      if (typing && !kSafeWhileTyping.contains(command)) {
        return KeyEventResult.ignored;
      }

      widget.onCommand(command);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,

      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

