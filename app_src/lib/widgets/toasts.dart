library;

import '../l10n/script.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';

/// Snackbars, raised where they can be seen.
///
/// The messenger draws inside the nearest `Scaffold`, and a sheet is a route over
/// it, so a bar raised from a sheet lands behind the sheet and looks like a tap
/// that did nothing. On a normal screen the messenger keeps its place above the
/// mini player; inside a popup the bar goes into the root overlay instead.
void _raise(
  BuildContext context, {
  required String message,
  required Duration duration,
  int? maxLines,
  String? actionLabel,
  Color? actionColor,
  VoidCallback? onAction,
  double? clearance,
}) {
  // Two ways to be buried: raised from inside a sheet or dialog, or raised by
  // a screen that now has one open on top of it (the shell's callbacks run in
  // the shell's context even when a sheet called them).
  final route = ModalRoute.of(context);
  final covered = route != null && !route.isCurrent;
  // Reduce Motion sends everything through the overlay: a `SnackBar` animates
  // itself, with a duration and a curve that are Flutter's and cannot be
  // shortened from here, so the one path that honours "no animations" is the
  // one this file draws.
  final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // A toast that sits on the bar is a toast that takes the bar's taps: for the
  // four seconds an undo is up, the mini player and the tabs underneath it go
  // dead. Screens below the shell read the height from the scope; the shell
  // itself cannot (its own context is above the widget that publishes it, and a
  // descendant does not exist when the call is made), so it passes the number.
  final inset = clearance ?? ToastClearance.of(context);

  if (!still && route is! PopupRoute && !covered) {
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
        margin: EdgeInsets.fromLTRB(12, 0, 12, inset + 12),
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
    inset,
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

void _raiseInOverlay(
  BuildContext context,
  double bottomInset,
  Widget content,
  Duration duration,
) {
  final overlay = Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) return;
  _dismiss();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastLayer(
      duration: duration,
      bottomInset: bottomInset,
      onDone: () {
        if (identical(_current, entry)) _dismiss();
      },
      child: content,
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

/// How much of the bottom of the screen a toast must keep clear.
///
/// The shell publishes the height of the bars it pins there — the mini player and
/// the tab row — so a toast lands above them instead of on them. Anything shown
/// outside the shell gets 0 and behaves as before.
class ToastClearance extends InheritedWidget {
  const ToastClearance({
    super.key,
    required this.height,
    required super.child,
  });

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToastClearance>()?.height ?? 0;

  @override
  bool updateShouldNotify(ToastClearance oldWidget) => oldWidget.height != height;
}

/// A short confirmation with nothing to act on.
void toast(BuildContext context, String message, {double? clearance}) {
  _raise(
    context,
    message: message,
    duration: const Duration(milliseconds: 1400),
    clearance: clearance,
  );
}

void toastUndo(
  BuildContext context,
  Skin skin,
  String message,
  VoidCallback undo, {
  double? clearance,
}) {
  _raise(
    context,
    message: message,
    duration: const Duration(seconds: 4),
    clearance: clearance,
    maxLines: 1,
    // Was the English word in an app that ships five locales: a Finnish user
    // got a Finnish sentence with an English button under it.
    actionLabel: l10nOf(context).commonUndo,
    actionColor: skin.accent,
    onAction: undo,
  );
}

void toastAction(
  BuildContext context,
  Skin skin,
  String message,
  String label,
  VoidCallback action, {
  double? clearance,
}) {
  _raise(
    context,
    message: message,
    duration: const Duration(seconds: 8),
    maxLines: 2,
    actionLabel: label,
    actionColor: skin.accent,
    onAction: action,
    clearance: clearance,
  );
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.child,
    required this.duration,
    required this.onDone,
    required this.bottomInset,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onDone;

  /// Pixels of the bottom of the screen occupied by the shell's bars.
  final double bottomInset;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  // Set from `Motion` in didChangeDependencies; a literal here would be a
  // second answer to a question the app answers once.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final fadeFor = Motion.of(context, const Duration(milliseconds: 160));
    _fade.duration = fadeFor;
    // `forward()` with a zero duration still waits for the ticker's first tick,
    // which is one frame of an invisible bar. Setting the value is the only way
    // to be there in the frame it appears.
    if (fadeFor == Duration.zero) {
      _fade.value = 1;
    } else {
      _fade.forward();
    }
  }

  late final Timer _life = Timer(widget.duration, () {
    if (!mounted) return;
    unawaited(_fade.reverse().whenComplete(widget.onDone));
  });

  // Under Reduce Motion the bar is simply there: 160ms of fade is not a
  // transition the user needs, and the timer still owns how long it stays.

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
      // Above the bars, not on them. See `ToastClearance`.
      bottom: widget.bottomInset,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),        child: Row(
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: trackingFor(context, 1.2),
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
