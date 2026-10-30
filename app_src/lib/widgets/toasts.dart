library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

/// Snackbars, in one place.
///
/// The shell and the screens had drifted: the shell raised floating bars in the
/// accent, cleared whatever was already showing, and offered an action; screens
/// called `ScaffoldMessenger.of(context).showSnackBar` by hand and got the
/// Material default. Same message, two apps. These three functions are the look,
/// so a message reads the same wherever it is raised.
/// A short confirmation. Nothing to act on, so no skin is needed.
void toast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 1400),
      behavior: SnackBarBehavior.floating,
    ));
}

void toastUndo(
  BuildContext context,
  Skin skin,
  String message,
  VoidCallback undo,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'UNDO',
        textColor: skin.accent,
        onPressed: undo,
      ),
    ));
}

void toastAction(
  BuildContext context,
  Skin skin,
  String message,
  String label,
  VoidCallback action,
) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 8),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: label,
        textColor: skin.accent,
        onPressed: action,
      ),
    ));
}
