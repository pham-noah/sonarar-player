library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/script.dart';
import '../theme/skin.dart';
import 'update_sheet.dart';
import 'update_ui.dart';

/// The offer to update, as one widget that looks after itself.
///
/// It reads the shell's one [UpdateUi] — the same object the update sheet and the
/// Settings row use — so it cannot claim a version the sheet has already
/// withdrawn.
///
/// When there is nothing newer it draws nothing at all — no empty row, no
/// reserved space.
class UpdateBar extends StatefulWidget {
  const UpdateBar({
    super.key,
    required this.skin,
    required this.ui,
    this.enabled = true,
  });

  final Skin skin;

  /// The update flow this bar is a view of.
  final UpdateUi ui;

  /// Off means no automatic check at all — not a check whose result is hidden.
  /// A manual check still fills the flow, and the bar shows what it finds.
  final bool enabled;

  @override
  State<UpdateBar> createState() => _UpdateBarState();
}

class _UpdateBarState extends State<UpdateBar> {
  @override
  void initState() {
    super.initState();
    widget.ui.addListener(_changed);

    // After the first frame: an update check must never sit in front of the app
    // opening.
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.ui.unawaitedCheck();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ui.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.ui;
    final update = ui.release;
    if (update == null) return const SizedBox.shrink();
    if (ui.phase != UpdatePhase.available &&
        ui.phase != UpdatePhase.downloading &&
        ui.phase != UpdatePhase.ready) {
      return const SizedBox.shrink();
    }

    final skin = widget.skin;
    final downloading = ui.phase == UpdatePhase.downloading;
    final progress = ui.progress;

    return Material(
      color: skin.panel,
      child: InkWell(
        onTap: () {
          unawaited(showUpdateSheet(context, ui, skin: skin, known: update));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.system_update_rounded, size: 18, color: skin.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  downloading
                      ? l10nOf(context).updateDownloading((progress * 100).round())
                      : l10nOf(context).updateIsOut(update.label),
                  style: TextStyle(
                    color: skin.textPrimary,
                    fontSize: LayoutSpec.fontFloor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                downloading ? '' : capsFor(context, l10nOf(context).updateSheetTitle),
                style: TextStyle(
                  color: skin.accent,
                  fontSize: LayoutSpec.fontFloor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: trackingFor(context, 1.2),
                ),
              ),
              if (downloading) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    color: skin.accent,
                    backgroundColor: skin.secondary(0.2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
