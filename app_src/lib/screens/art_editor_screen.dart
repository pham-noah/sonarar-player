library;

import 'package:flutter/material.dart';

import '../art/art_focus.dart';
import '../art/art_spec.dart';
import '../theme/skin.dart';
import '../widgets/art_scrim.dart';
import '../widgets/framed_art.dart';

/// Places one picture inside its frame, full screen, with the real thing in
/// front of you. What you see while dragging is what the player draws, because
/// both go through [FramedArt] with the same [ArtSpec].
class ArtEditorScreen extends StatefulWidget {
  const ArtEditorScreen({
    super.key,
    required this.skin,
    required this.assetPath,
    required this.aspect,
    required this.focus,
    required this.initial,
  });

  final Skin skin;
  final String assetPath;
  final double aspect;
  final ArtFocus focus;
  final ArtSpec initial;

  @override
  State<ArtEditorScreen> createState() => _ArtEditorScreenState();
}

class _ArtEditorScreenState extends State<ArtEditorScreen> {
  late ArtSpec _spec = widget.initial;

  void _update(ArtSpec next) => setState(() => _spec = next);

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return Scaffold(
      key: const Key('art-editor'),
      backgroundColor: skin.background,
      appBar: AppBar(
        backgroundColor: skin.background,
        foregroundColor: skin.textPrimary,
        title: Text(
          'ADJUST ART',
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
            color: skin.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _update(ArtSpec.none),
            child: Text('RESET', style: TextStyle(color: skin.textSecondary)),
          ),
          TextButton(
            key: const Key('art-save'),
            // Framing goes back to the caller: a bundle keeps it beside the
            // pictures, built-in art keeps it in the look file.
            onPressed: () => Navigator.of(context).pop(_spec),
            child: Text(
              'SAVE',
              style: TextStyle(color: skin.accent, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              // Drag the picture where you want it; the numbers follow.
              onPanUpdate: (details) => _update(
                _spec.copyWith(
                  dx: _spec.dx + details.delta.dx / 120,
                  dy: _spec.dy + details.delta.dy / 120,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FramedArt(
                      assetPath: widget.assetPath,
                      aspect: widget.aspect,
                      focus: widget.focus,
                      spec: _spec,
                      burn: _spec.fade,
                    ),
                  ),
                  // The player dims the left third behind the title; framing
                  // has to be judged against that, not against a clean image.
                  Positioned.fill(child: ArtScrim(color: widget.skin.background)),
                  // The edge of what the player will show. Without it, a zoomed
                  // picture looks identical to a fitted one.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.skin.accent.withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: skin.panel,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slider(
                  skin,
                  'ZOOM',
                  _spec.zoom,
                  ArtSpec.minZoom,
                  ArtSpec.maxZoom,
                  (v) => _update(_spec.copyWith(zoom: v)),
                  (v) => '${v.toStringAsFixed(1)}x',
                ),
                _slider(
                  skin,
                  'ROTATE',
                  _spec.rotationDeg,
                  -ArtSpec.maxRotation,
                  ArtSpec.maxRotation,
                  (v) => _update(_spec.copyWith(rotationDeg: v)),
                  (v) => '${v.round()}°',
                ),
                _slider(
                  skin,
                  'FADE',
                  _spec.fade,
                  0,
                  1,
                  (v) => _update(_spec.copyWith(fade: v)),
                  (v) => '${(v * 100).round()}%',
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _update(_spec.copyWith(flipX: !_spec.flipX)),
                      icon: Icon(
                        Icons.flip_rounded,
                        color: skin.accent,
                        size: 18,
                      ),
                      label: Text(
                        _spec.flipX ? 'MIRRORED' : 'MIRROR',
                        style: TextStyle(color: skin.textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(
    Skin skin,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String Function(double) format,
  ) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(
          label,
          style: TextStyle(
            color: skin.textSecondary,
            fontSize: LayoutSpec.fontFloor - 4,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: skin.accent,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 52,
        child: Text(
          format(value),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: skin.accent,
            fontSize: LayoutSpec.fontFloor - 4,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}
