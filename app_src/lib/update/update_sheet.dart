/// The sheet the update check answers in.
///
/// The offer used to be a strip that downloaded the moment you touched it and then
/// threw the file at the installer: no size, no notes, no progress worth watching,
/// and nothing to say when a download failed. This is the same offer as a real
/// flow — the version, what changed, how big it is, then Download, then Install.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../l10n/script.dart';
import '../theme/skin.dart';
import 'update_service.dart';
import 'update_ui.dart';

Future<void> showUpdateSheet(
  BuildContext context,
  UpdateUi ui, {
  required Skin skin,
  AppUpdate? known,
}) {
  ui.open(known: known);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: skin.panel,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => UpdateSheetBody(ui: ui, skin: skin),
  );
}

class UpdateSheetBody extends StatelessWidget {
  const UpdateSheetBody({super.key, required this.ui, required this.skin});

  final UpdateUi ui;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ui,
      builder: (context, _) {
        final l10n = l10nOf(context);
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update_rounded, size: 18, color: skin.accent),
                    const SizedBox(width: 10),
                    Text(
                      capsFor(context, l10n.updateSheetTitle),
                      style: TextStyle(
                        color: skin.textPrimary,
                        fontSize: LayoutSpec.fontRow,
                        fontWeight: FontWeight.w900,
                        letterSpacing: trackingFor(context, 1.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ..._body(context, l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n) {
    final release = ui.release;
    switch (ui.phase) {
      case UpdatePhase.checking:
        return [
          _line(context, l10n.updateChecking),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 3,
            color: skin.accent,
            backgroundColor: skin.secondary(0.2),
          ),
        ];

      case UpdatePhase.available:
      case UpdatePhase.downloading:
      case UpdatePhase.ready:
        if (release == null) return [_line(context, l10n.settingsOnNewest(''))];
        final notes = release.notesPreview;
        return [
          Text(
            l10n.updateIsOut(release.label),
            style: TextStyle(
              color: skin.textPrimary,
              fontSize: LayoutSpec.fontRow,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Text(
                  notes,
                  style: TextStyle(
                    color: skin.textSecondary,
                    fontSize: LayoutSpec.fontMicro,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
          if (release.sizeBytes > 0) ...[
            const SizedBox(height: 10),
            _line(context, l10n.updateSizeMb(megabytesOf(release.sizeBytes))),
          ],
          const SizedBox(height: 16),
          _action(context, l10n),
        ];

      case UpdatePhase.upToDate:
        return [
          _line(context, l10n.settingsOnNewest(ui.release?.version ?? '')),
          const SizedBox(height: 14),
          _button(context, l10n.updateCheckAgain, () => ui.checkNow(), primary: false),
        ];

      case UpdatePhase.failed:
        return [
          _line(
            context,
            ui.failure == 'incomplete'
                ? l10n.updateDidNotFinish
                : (ui.failure == 'refused'
                    ? l10n.updateInstallRefusedHint
                    : l10n.updateDidNotFinish),
          ),
          const SizedBox(height: 14),
          _button(
            context,
            ui.apk == null ? l10n.updateCheckAgain : l10n.updateInstall,
            ui.apk == null ? () => ui.checkNow() : () => ui.installNow(),
            primary: ui.apk != null,
          ),
        ];

      case UpdatePhase.idle:
        return [
          const SizedBox(height: 4),
          _button(context, l10n.settingsCheckNow, () => ui.checkNow()),
        ];
    }
  }

  Widget _action(BuildContext context, AppLocalizations l10n) {
    switch (ui.phase) {
      case UpdatePhase.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _line(context, l10n.updateDownloading((ui.progress * 100).round())),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ui.progress,
              minHeight: 6,
              color: skin.accent,
              backgroundColor: skin.secondary(0.2),
            ),
          ],
        );

      case UpdatePhase.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _button(context, l10n.updateInstall, () => ui.installNow()),
            const SizedBox(height: 8),
            Text(
              l10n.updateInstallRefusedHint,
              style: TextStyle(color: skin.secondary(0.7), fontSize: LayoutSpec.fontMicro),
            ),
          ],
        );

      default:
        return _button(context, l10n.updateDownload, () => ui.downloadNow());
    }
  }

  Widget _button(BuildContext context, String label, VoidCallback onTap,
      {bool primary = true}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? skin.accent : skin.secondary(0.12),
          foregroundColor: primary ? skin.onAccent : skin.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          // Uppercase follows the script being drawn: Japanese and Chinese are
          // neither upper-cased nor tracked, which is the app's rule everywhere.
          capsFor(context, label),
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w900,
            letterSpacing: trackingFor(context, 1.2),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String text) => Text(
        text,
        style: TextStyle(color: skin.textSecondary, fontSize: LayoutSpec.fontMicro),
      );
}
