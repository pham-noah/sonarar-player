import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';

import '../backup/backup_service.dart';
import '../theme/skin.dart';
import '../widgets/devices.dart';

/// What a failed backup or restore says. The service returns a reason, not a
/// sentence, so the words live here with every other word the app shows.
String? _problemText(
  AppLocalizations l10n,
  BackupProblem? problem,
  String? detail,
) => switch (problem) {
      null => null,
      BackupProblem.nothingToBackUp => l10n.backupNoState,
      BackupProblem.notABackup => l10n.backupNotOurs,
      BackupProblem.unreadableJson => l10n.backupUnreadableJson,
      BackupProblem.unreadableFile => l10n.backupUnreadableFile(detail ?? ''),
      BackupProblem.newerVersion => l10n.backupNewerVersion,
      BackupProblem.noData => l10n.backupNoData,
      BackupProblem.nothingRestored => l10n.backupNothingRestored,
      BackupProblem.writeFailed => l10n.backupWriteFailed(detail ?? ''),
      BackupProblem.restoreFailed => l10n.backupRestoreStopped(detail ?? ''),
    };

/// BACKUP NOW / RESTORE on the Settings page.
///
/// Lives in the page rather than in the shell because it needs a `SnackBar`
/// and nothing else: the work is [BackupService], which knows no widgets.
class BackupSection extends StatefulWidget {
  const BackupSection({
    super.key,
    required this.skin,
    required this.stateDirectory,
    required this.downloadDirectory,
    required this.row,
    this.appVersion,
  });

  final Skin skin;
  final String stateDirectory;
  final String downloadDirectory;
  final String? appVersion;

  /// The caller owns the row styling so this block matches the page it sits on.
  final Widget Function({
    required String label,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) row;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  BackupService get _service =>
      BackupService(stateDirectory: Directory(widget.stateDirectory));

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final report = await _service.writeTo(
      Directory(widget.downloadDirectory),
      appVersion: widget.appVersion,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _say(
      report.ok
          ? 'Saved ${report.files} files to ${report.file!.path}'
          : _problemText(l10nOf(context), report.problem, report.detail) ?? l10nOf(context).backupFailed,
    );
  }

  Future<void> _restore() async {
    if (_busy) return;
    final found = BackupService.findBackups(Directory(widget.downloadDirectory));
    if (found.isEmpty) {
      _say(l10nOf(context).backupNoneFound);
      return;
    }
    final picked = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.skin.panel,
        title: Text(
          l10nOf(context).backupRestore,
          style: TextStyle(
            color: widget.skin.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10nOf(context).backupRestoreNote,
                style: TextStyle(
                  fontSize: LayoutSpec.fontMicro,
                  height: 1.35,
                  color: widget.skin.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final f in found.take(6))
                InkWell(
                  onTap: () => Navigator.of(ctx).pop(f),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(
                      f.uri.pathSegments.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontMicro,
                        color: widget.skin.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              l10nOf(context).libraryCancel,
              style: TextStyle(color: widget.skin.textSecondary),
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;

    setState(() => _busy = true);
    final report = await _service.restore(picked);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!report.ok) {
      _say(_problemText(l10nOf(context), report.problem, report.detail) ?? l10nOf(context).backupRestoreFailed);
      return;
    }
    // Stores are opened once at launch and cached, so a restore on screen
    // cannot repaint itself — say what to do instead of pretending.
    _say('Restored ${report.files} files. Close and reopen Sonarar to load them.');
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: LayoutSpec.fontMicro)),
          backgroundColor: widget.skin.panel,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionBand(skin: skin, label: l10nOf(context).backupYourData),
        widget.row(
          label: l10nOf(context).backupNow,
          icon: Icons.save_alt_rounded,
          trailing: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: skin.accent,
                  ),
                )
              : Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: skin.secondary(0.6),
                ),
          onTap: _busy ? null : _save,
        ),
        widget.row(
          label: l10nOf(context).backupRestoreTitle,
          icon: Icons.settings_backup_restore_rounded,
          trailing: Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: skin.secondary(0.6),
          ),
          onTap: _busy ? null : _restore,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            l10nOf(context).backupWhatItHolds,
            style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
