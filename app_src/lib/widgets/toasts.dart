library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/skin.dart';

/// Snackbars, raised where they can be seen.
///
/// A `ScaffoldMessenger` puts its bar inside the nearest `Scaffold`, and a modal
/// sheet is a route painted *over* that scaffold. Measured in
/// `test/shots/toast_over_sheet_shot.dart`: a bar raised from inside a sheet sat
/// at y 697–780 while the sheet covered 559–844 — present in the tree, invisible
/// on screen, so the sheet looked like it had ignored the tap.
///
/// One entry point, two exits:
///
///  * On a normal screen the messenger does it, so the bar sits above the mini
///    player exactly as it always has.
///  * Inside a popup route — sheet, dialog — the bar goes into the root
///    navigator's overlay last, which is above every route. Same Material
///    geometry, drawn by hand.
///
/// The look does not change; only the places where a bar could be buried do.
void _raise(
  BuildContext context, {
  required String message,
  required Duration duration,
  int? maxLines,
  String? actionLabel,
  Color? actionColor,
  VoidCallback? onAction,
}) {
  // Two ways to be buried: raised from inside a sheet or dialog, or raised by
  // a screen that now has one open on top of it (the shell's callbacks run in
  // the shell's context even when a sheet called them).
  final route = ModalRoute.of(context);
  final covered = route != null && !route.isCurrent;
  if (route is! PopupRoute && !covered) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: maxLines == null
            ? Text(message)
            : Text(message, maxLines: maxLines, overflow: TextOverflow.ellipsis),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: actionColor,
                onPressed: onAction,
              ),
      ));
    return;
  }
  _raiseInOverlay(
    context,
    _ToastCard(
      theme: Theme.of(context),
      message: message,
      maxLines: maxLines ?? 2,
      actionLabel: actionLabel,
      actionColor: actionColor,
      onAction: onAction,
    ),
    duration,
  );
}

OverlayEntry? _current;
Timer? _timer;

void _dismiss() {
  _timer?.cancel();
  _timer = null;
  _current?.remove();
  _current = null;
}

void _raiseInOverlay(BuildContext context, Widget content, Duration duration) {
  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  _dismiss();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastLayer(
      duration: duration,
      onDone: () {
        if (identical(_current, entry)) _dismiss();
      },
      child: content,
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

/// A short confirmation with nothing to act on.
void toast(BuildContext context, String message) {
  _raise(
    context,
    message: message,
    duration: const Duration(milliseconds: 1400),
  );
}

void toastUndo(
  BuildContext context,
  Skin skin,
  String message,
  VoidCallback undo,
) {
  _raise(
    context,
    message: message,
    duration: const Duration(seconds: 4),
    maxLines: 1,
    actionLabel: 'UNDO',
    actionColor: skin.accent,
    onAction: undo,
  );
}

void toastAction(
  BuildContext context,
  Skin skin,
  String message,
  String label,
  VoidCallback action,
) {
  _raise(
    context,
    message: message,
    duration: const Duration(seconds: 8),
    maxLines: 2,
    actionLabel: label,
    actionColor: skin.accent,
    onAction: action,
  );
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.child,
    required this.duration,
    required this.onDone,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  )..forward();

  late final Timer _life = Timer(widget.duration, () {
    if (!mounted) return;
    unawaited(_fade.reverse().whenComplete(widget.onDone));
  });

  @override
  void dispose() {
    _life.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.theme,
    required this.message,
    required this.maxLines,
    this.actionLabel,
    this.actionColor,
    this.onAction,
  });

  final ThemeData theme;
  final String message;
  final int maxLines;
  final String? actionLabel;
  final Color? actionColor;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final bar = theme.snackBarTheme;
    final background = bar.backgroundColor ?? theme.colorScheme.inverseSurface;
    final foreground =
        bar.contentTextStyle?.color ?? theme.colorScheme.onInverseSurface;
    return Material(
      key: const ValueKey('sonarar-toast'),
      color: background,
      elevation: bar.elevation ?? 6,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                message,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: (bar.contentTextStyle ?? const TextStyle(fontSize: 14))
                    .copyWith(color: foreground),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: actionColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
