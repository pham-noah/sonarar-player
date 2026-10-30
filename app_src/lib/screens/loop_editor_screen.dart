library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/track.dart';
import '../playback/loop_points.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../widgets/pressable.dart';

class LoopEditorScreen extends StatefulWidget {
  const LoopEditorScreen({
    super.key,
    required this.state,
    required this.track,
    required this.points,
    required this.position,
    required this.duration,
    required this.onSave,
    this.onPreview,
  });

  final AppState state;
  final Track track;

  final LoopPoints? points;

  final ValueListenable<Duration> position;

  final ValueListenable<Duration> duration;

  final Future<void> Function(LoopPoints) onSave;

  final Future<void> Function(bool playing)? onPreview;

  @override
  State<LoopEditorScreen> createState() => _LoopEditorScreenState();
}

class _LoopEditorScreenState extends State<LoopEditorScreen> {
  Duration? _introEnd;
  Duration? _loopStart;
  Duration? _loopEnd;
  int _loopCount = 2;
  bool _previewing = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final p = widget.points;
    _introEnd = p?.introEnd;
    _loopStart = p?.loopStart;
    _loopEnd = p?.loopEnd;
    _loopCount = p?.loopCount ?? 2;
  }

  Duration get _now => widget.position.value;

  LoopPoints _draft() => LoopPoints(
        trackId: widget.track.id,
        introEnd: _introEnd,
        loopStart: _loopStart,
        loopEnd: _loopEnd,
        loopCount: _loopCount,
      );

  String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    await widget.onSave(_draft());
    if (!mounted) return;
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.state.uiSkin;
    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(
        child: ListView(
          padding: LayoutSpec.screenPadding,
          children: [
            Text(
              'LOOP',
              style: TextStyle(
                fontSize: LayoutSpec.fontTitle,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 22),

            ValueListenableBuilder<Duration>(
              valueListenable: widget.position,
              builder: (_, pos, __) => Text(
                _mmss(pos),
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: skin.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),

            const SizedBox(height: 18),
            _markRow(
              skin,
              'INTRO ENDS',
              _introEnd,
              onSet: () => setState(() => _introEnd = _now),
              onClear: () => setState(() => _introEnd = null),
            ),
            _markRow(
              skin,
              'LOOP START',
              _loopStart,
              onSet: () => setState(() => _loopStart = _now),
              onClear: () => setState(() => _loopStart = null),
            ),
            _markRow(
              skin,
              'LOOP END',
              _loopEnd,
              onSet: () => setState(() => _loopEnd = _now),
              onClear: () => setState(() => _loopEnd = null),
            ),

            const SizedBox(height: 22),
            SectionLabel(skin: skin, text: 'REPEAT'),
            Row(
              children: [
                for (final n in [1, 2, 3, 0])
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _countChip(skin, n),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _loopCount == 0
                  ? 'No repeat. The track just plays to its end.'
                  : 'Repeats $_loopCount time${_loopCount == 1 ? '' : 's'}, then fades.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
              ),
            ),

            const SizedBox(height: 26),

            if (_loopEnd != null && _loopStart != null && _loopEnd! <= _loopStart!)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'LOOP END is before LOOP START — this will not repeat.',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    color: skin.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),

            Row(
              children: [
                Expanded(
                  child: Pressable(
                    child: OutlinedButton(
                      onPressed: () async {
                        final next = !_previewing;
                        setState(() => _previewing = next);
                        await widget.onPreview?.call(next);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: skin.accent,
                        side: BorderSide(color: skin.accent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_previewing ? 'PAUSE' : 'PLAY'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Pressable(
                    child: OutlinedButton(
                      onPressed: _saved ? null : _save,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: skin.onAccent,
                        backgroundColor: skin.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_saved ? 'SAVED' : 'SAVE'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Play the track, tap a marker where you hear the loop, then save. '
              'A track with no markers plays exactly as it always did.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countChip(Skin skin, int n) {
    final selected = _loopCount == n;
    return Pressable(
      child: InkWell(
        onTap: () => setState(() => _loopCount = n),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: LayoutSpec.tapTarget,
            minHeight: LayoutSpec.tapTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? skin.panel : Colors.transparent,
            border: Border.all(
              color: selected ? skin.accent : skin.secondary(0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            n == 0 ? 'OFF' : 'x$n',
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              fontWeight: FontWeight.w800,
              color: skin.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _markRow(
    Skin skin,
    String label,
    Duration? value, {
    required VoidCallback onSet,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: skin.textPrimary,
              ),
            ),
          ),
          Text(
            value == null ? '—' : _mmss(value),
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              color: value == null ? skin.textSecondary : skin.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Pressable(
            child: OutlinedButton(
              onPressed: onSet,
              style: OutlinedButton.styleFrom(
                foregroundColor: skin.textPrimary,
                side: BorderSide(color: skin.accent),
                minimumSize: const Size(64, LayoutSpec.tapTarget),
              ),
              child: const Text('SET'),
            ),
          ),
          if (value != null)
            IconButton(
              onPressed: onClear,
              icon: Icon(Icons.close_rounded, color: skin.textSecondary),
              tooltip: 'Clear $label',
            ),
        ],
      ),
    );
  }
}
