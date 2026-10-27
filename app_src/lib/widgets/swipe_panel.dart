library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

enum SwipeSide { left, right }

class SwipePanel extends StatelessWidget {
  const SwipePanel({
    super.key,
    required this.side,
    required this.progress,
    required this.icon,
    required this.label,
    required this.skin,
  });

  final SwipeSide side;

  final double progress;

  final IconData icon;
  final String label;
  final Skin skin;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final atRight = side == SwipeSide.right;

    return Container(

      alignment: atRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.only(
        left: atRight ? 0 : 20,
        right: atRight ? 20 : 0,
      ),
      decoration: BoxDecoration(
        color: skin.accent.withValues(alpha: 0.28 * p),
        border: Border.all(
          color: skin.accent.withValues(alpha: p),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!atRight) ...[
            _icon(p),

            if (p > 0.55) ...[const SizedBox(width: 6), _label()],
          ] else ...[
            if (p > 0.55) ...[_label(), const SizedBox(width: 6)],
            _icon(p),
          ],
        ],
      ),
    );
  }

  Widget _icon(double p) => Icon(
        icon,
        color: skin.accent,
        size: 22 * p.clamp(0.55, 1.0),
      );

  Widget _label() => Text(
        label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: LayoutSpec.fontLabel,
          letterSpacing: 2,
          fontWeight: FontWeight.w900,
          color: skin.accent,
        ),
      );
}
