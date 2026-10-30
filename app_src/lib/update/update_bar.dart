library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../core/build_info.dart';
import '../theme/skin.dart';
import '../widgets/toasts.dart';
import 'update_service.dart';

/// The offer to update, as one widget that looks after itself.
///
/// It keeps its own state and its own download, so the shell only has to place
/// it. When there is nothing newer it draws nothing at all — no empty row, no
/// reserved space.
class UpdateBar extends StatefulWidget {
  const UpdateBar({
    super.key,
    required this.skin,
    this.enabled = true,
    this.check,
  });

  final Skin skin;

  /// Off means no check at all — not a check whose result is hidden.
  final bool enabled;

  /// The check itself, replaceable so a test can see whether it ran.
  final Future<AppUpdate?> Function()? check;

  @override
  State<UpdateBar> createState() => _UpdateBarState();
}

class _UpdateBarState extends State<UpdateBar> {
  AppUpdate? _update;
  double? _progress;

  @override
  void initState() {
    super.initState();
    // After the first frame: an update check must never sit in front of the
    // app opening.
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_check());
    });
  }

  Future<void> _check() async {
    final update =
        await (widget.check ?? () => checkForUpdate(appVersionCode))();
    if (!mounted || update == null) return;
    setState(() => _update = update);
  }

  Future<void> _download(AppUpdate update) async {
    final downloads = await getDownloadsDirectory();
    if (downloads == null || !mounted) return;
    setState(() => _progress = 0);
    final file = await downloadUpdate(
      update,
      downloads,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() => _progress = null);
    if (file == null) {
      toast(context, 'The download did not finish. Try again.');
      return;
    }
    // The system installer still asks; this only offers the file to it.
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    final skin = widget.skin;
    final progress = _progress;

    return Material(
      color: skin.panel,
      child: InkWell(
        onTap: progress == null ? () => _download(update) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.system_update_rounded, size: 18, color: skin.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress == null
                      ? '${update.label} is out'
                      : 'Downloading ${(progress * 100).round()}%',
                  style: TextStyle(
                    color: skin.textPrimary,
                    fontSize: LayoutSpec.fontFloor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                progress == null ? 'UPDATE' : '',
                style: TextStyle(
                  color: skin.accent,
                  fontSize: LayoutSpec.fontFloor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              if (progress != null) ...[
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
