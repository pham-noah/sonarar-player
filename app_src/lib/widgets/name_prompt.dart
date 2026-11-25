library;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/skin.dart';

/// Asks for a name, and answers with one or with null. An empty or whitespace-only
/// answer is null, so no caller has to decide what an empty name means.
Future<String?> askForName(
  BuildContext context,
  Skin skin, {
  required String title,
  // Null means "the usual word", resolved from the ARB below. The defaults used
  // to be English literals ('SAVE', 'Name', 'CANCEL' in the buttons) while the
  // same three strings sat translated in every locale already.
  String? confirm,
  String? hint,
}) async {
  final l = l10nOf(context);
  final controller = TextEditingController();
  try {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: skin.background,
        title: Text(title, style: TextStyle(color: skin.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: skin.textPrimary),
          decoration: InputDecoration(hintText: hint ?? l.libraryPlaylistName),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.libraryCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(confirm ?? l.importSave),
          ),
        ],
      ),
    );
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? null : trimmed;
  } finally {
    controller.dispose();
  }
}
