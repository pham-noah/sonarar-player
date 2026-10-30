library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/diag_log.dart';
import '../library/storage_permission.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import 'spectrum_probe_screen.dart';
import '../theme/slab.dart';
import '../widgets/pressable.dart';
import '../widgets/toasts.dart';

class DiagnosticsPanel extends StatefulWidget {
  const DiagnosticsPanel({
    super.key,
    required this.skin,
    required this.log,
    this.presentation,
  });

  final Skin skin;

  final Presentation? presentation;
  final DiagLog log;

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  bool _problemsOnly = true;
  StorageAccess? _access;
  bool _asking = false;

  @override
  void initState() {
    super.initState();

    widget.log.addListener(_onLog);
    unawaited(_readAccess());
  }

  Future<void> _readAccess() async {
    final a = await StoragePermission.status();
    if (mounted) setState(() => _access = a);
  }

  Future<void> _askAccess() async {
    if (_asking) return;
    setState(() => _asking = true);
    await StoragePermission.request();
    await _readAccess();
    if (mounted) setState(() => _asking = false);
  }

  /// Every write failure in this app — a download, a cover, a playlist — comes
  /// back as EPERM when this is off, and none of those messages say why. One
  /// line here turns a screenshot into a diagnosis.
  Widget _accessStrip(Skin skin) {
    final a = _access;
    final ok = a == StorageAccess.granted;
    final label = switch (a) {
      null => 'CHECKING STORAGE ACCESS…',
      StorageAccess.granted => 'ALL FILES ACCESS GRANTED',
      StorageAccess.denied =>
        'NO ALL-FILES ACCESS — downloads and covers cannot be written',
      StorageAccess.unknown => 'STORAGE ACCESS UNKNOWN',
    };

    return InkWell(
      onTap: ok || a == null ? null : _askAccess,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              ok ? Icons.folder_open_rounded : Icons.lock_outline_rounded,
              size: 15,
              color: ok ? skin.accent : skin.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: ok ? skin.textSecondary : skin.accent,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (!ok && a != null)
              Text(
                'GRANT',
                style: TextStyle(
                  color: skin.accent,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.log.removeListener(_onLog);
    super.dispose();
  }

  void _onLog() {
    if (mounted) setState(() {});
  }

  Future<void> _share() async {
    final text = widget.log.asText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    toast(context, 'Log copied (${widget.log.length} lines) — paste it anywhere');
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final lines = _problemsOnly ? widget.log.problems : widget.log.lines;
    final reading = _problemsOnly ? widget.log.problems : widget.log.lines;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          Row(
            children: [
              _seg(skin, 'PROBLEMS', widget.log.problems.length, _problemsOnly,
                  () => setState(() => _problemsOnly = true)),
              const SizedBox(width: 8),
              _seg(skin, 'ALL', widget.log.length, !_problemsOnly,
                  () => setState(() => _problemsOnly = false)),
              const Spacer(),
              if (widget.log.length > 0)
                Pressable(
                  child: InkWell(
                    onTap: () => setState(widget.log.clear),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text('CLEAR',
                          style: TextStyle(
                              color: skin.textSecondary,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              Pressable(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const SpectrumProbeScreen(),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(children: [
                      Icon(Icons.graphic_eq_rounded, size: 15, color: skin.accent),
                      const SizedBox(width: 6),
                      Text('SPECTRUM',
                          style: TextStyle(
                              color: skin.accent,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pressable(
                child: InkWell(
                  onTap: _share,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(children: [
                      Icon(Icons.copy_rounded, size: 15, color: skin.accent),
                      const SizedBox(width: 6),
                      Text('COPY',
                          style: TextStyle(
                              color: skin.accent,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
          _accessStrip(skin),
          const SizedBox(height: 2),

          if (lines.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _problemsOnly
                      ? 'Nothing has gone wrong this run.'
                      : 'Nothing has been logged yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: skin.textSecondary, fontSize: 15),
                ),
              ),
            )
          else
            Expanded(
              child: Slab(
        presentation: widget.presentation,
                skin: skin,
                fill: skin.panel,
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: lines.length,

                  itemBuilder: (_, i) {
                    final l = _problemsOnly ? lines[i] : reading[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${l.stamp}  ',
                            style: TextStyle(
                                color: skin.textSecondary, fontSize: 12, height: 1.35),
                          ),
                          TextSpan(
                            text: l.text,
                            style: TextStyle(
                              color: l.looksWrong ? skin.accent : skin.textPrimary,
                              fontSize: 16,
                              height: 1.35,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _seg(Skin skin, String label, int count, bool on, VoidCallback onTap) {
    return Pressable(
      child: InkWell(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(

          color: on ? skin.accent : skin.panel,
          border: Border.all(color: on ? skin.accent : skin.accentDeep),
        ),
        child: Text(
          '$label${count > 0 ? ' $count' : ''}',
          style: TextStyle(
            color: on ? skin.onAccent : skin.textSecondary,
            fontSize: 12,
            letterSpacing: 1.1,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
          ),
          ),
        ),
      ),
    );
  }
}
