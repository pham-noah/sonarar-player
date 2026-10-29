import 'dart:async';

import 'theme_preset.dart';

/// Keeps the theme file in step with edits.
///
/// Editing a theme is a live operation — dragging an accent, nudging framing —
/// so writing on every change means the whole preset list hits the disk dozens
/// of times a second. This waits for the hand to stop, then writes once.
class ThemeSession {
  ThemeSession({
    required this.save,
    this.settle = const Duration(milliseconds: 400),
  });

  final Future<void> Function(List<ThemePreset> presets) save;
  final Duration settle;

  Timer? _timer;
  List<ThemePreset>? _pending;

  /// Called when an edit has been folded into the active theme.
  void touched(List<ThemePreset> presets) {
    _pending = presets;
    _timer?.cancel();
    _timer = Timer(settle, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final presets = _pending;
    _pending = null;
    if (presets != null) await save(presets);
  }

  void dispose() {
    _timer?.cancel();
    final presets = _pending;
    _pending = null;
    if (presets != null) unawaited(save(presets));
  }
}
