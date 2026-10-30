library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

/// Asks for a name, and answers with one or with null.
///
/// The shell had two of these — new playlist, save queue — identical down to the
/// hint text and differing only in the title and the button word. One of them
/// never disposed its controller. Both go through here now.
///
/// An empty or whitespace-only answer is null, so no caller has to remember to
/// trim before deciding what an empty name means.
Future<String?> askForName(
  BuildContext context,
  Skin skin, {
  required String title,
  String confirm = 'SAVE',
  String hint = 'Name',
}) async {
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
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(confirm),
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
