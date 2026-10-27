library;

import 'package:flutter/material.dart';

import '../art/art_focus.dart';
import '../art/skin_art.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../widgets/framed_art.dart';

class ArtFramingPanel extends StatelessWidget {
  const ArtFramingPanel({
    super.key,
    required this.skin,
    required this.piece,
    required this.focus,
    required this.onFocus,
    required this.onReset,
    this.customised = false,
  });

  final Skin skin;

  final SkinArt piece;

  final ArtFocus focus;
  final void Function(ArtFocus) onFocus;
  final VoidCallback onReset;

  final bool customised;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _preview(context),
        const SizedBox(height: LayoutSpec.gapM),
        _zoomRow(context),
        const SizedBox(height: LayoutSpec.gapS),
        _resetRow(context),
      ],
    );
  }

  Widget _preview(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = (w * 0.55).clamp(140.0, 230.0);
        final slot = Size(w, h);

        final reach = reachFor(
          srcW: piece.aspect,
          srcH: 1.0,
          slotW: slot.width,
          slotH: slot.height,
          zoom: focus.zoom,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            final next = focus.copyWith(
              dx: focus.dx + d.delta.dx * (2.0 / slot.width),
              dy: focus.dy - d.delta.dy * (2.0 / slot.height),
            );
            onFocus(next);
          },
          child: SizedBox(
            height: h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: skin.textSecondary.withValues(alpha: 0.35),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FramedArt(
                    assetPath: piece.assetPath,
                    aspect: piece.aspect,
                    focus: focus,
                    cacheWidth: 600,
                  ),

                  Center(
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: skin.accent.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          _reachTick(skin, 'X', reach.x),
                          const SizedBox(width: 8),
                          _reachTick(skin, 'Y', reach.y),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reachTick(Skin skin, String axis, double amount) {
    return Expanded(
      child: Row(
        children: [
          Text(
            axis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w900,
              color: skin.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Stack(
              children: [
                Container(height: 3, color: skin.textSecondary.withValues(alpha: 0.3)),
                FractionallySizedBox(
                  widthFactor: amount.clamp(0.0, 1.0),
                  child: Container(height: 3, color: skin.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomRow(BuildContext context) {
    return Row(
      children: [
        Text(
          'ZOOM',
          style: TextStyle(
            fontSize: LayoutSpec.fontLabel,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: skin.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: skin.accent,
              inactiveTrackColor: skin.textSecondary.withValues(alpha: 0.3),
              thumbColor: skin.accent,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: focus.zoom.clamp(kMinArtZoom, kMaxArtZoom),
              min: kMinArtZoom,
              max: kMaxArtZoom,
              onChanged: (v) => onFocus(focus.copyWith(zoom: v)),
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${focus.zoom.toStringAsFixed(2)}×',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              fontWeight: FontWeight.w900,
              color: skin.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _resetRow(BuildContext context) {
    return Row(
      children: [
        SkinChip(
          skin: skin,
          label: 'RESET',
          icon: Icons.restart_alt_rounded,
          selected: customised,
          onTap: customised ? onReset : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            customised
                ? 'Framed by you. Tap the art and drag it, or use the controls.'
                : 'At its default framing for this piece.',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
