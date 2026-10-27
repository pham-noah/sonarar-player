library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'skin.dart';
import 'surface.dart';

class Slab extends StatelessWidget {
  const Slab({
    super.key,
    required this.skin,
    required this.child,
    this.accentEdge = true,
    this.active = false,
    this.fill,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 18, 14),
    this.onTap,
    this.skewScale = 0.45,
    this.presentation,
    this.radius = 0,
  });

  final double radius;

  final Skin skin;
  final Widget child;

  final bool accentEdge;

  final bool active;

  final Color? fill;

  final EdgeInsets padding;
  final VoidCallback? onTap;

  final double skewScale;

  final Presentation? presentation;

  @override
  Widget build(BuildContext context) {
    final base = presentation ?? Presentation.forSkin(skin);
    return Surface(
      presentation: skewScale == 1.0
          ? base
          : Presentation(
              layout: base.layout,
              palette: base.palette,
              material: base.material,
              motion: base.motion,
              arrangement: base.arrangement,

              kit: base.kit,

              skewDegrees: base.skewDegrees * skewScale,
            ),
      role: SurfaceRole.card,
      fill: fill ??
          (active
              ? skin.accent
              : base.kit.material.transparentInactiveFill
                  ? const Color(0x00000000)
                  : base.palette.surface),
      accentEdge: accentEdge,
      active: active,
      radius: radius,
      padding: padding,
      child: onTap == null
          ? child
          : GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: child),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.skin,
    required this.text,
    this.trailing,
  });

  final Skin skin;
  final String text;

  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LayoutSpec.gapS),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
                color: skin.accent,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
                color: skin.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.skin, required this.text});

  final Skin skin;
  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: LayoutSpec.fontTitle,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: skin.textPrimary,
        ),
      ),
    );
  }
}

class SkinChip extends StatelessWidget {
  const SkinChip({
    super.key,
    required this.skin,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
  });

  final Skin skin;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final rad = skin.skewDegrees * (3.14159265 / 180) * 0.12;
    final fg = selected ? skin.accent : skin.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Transform(
        transform: Matrix4.skewX(-rad),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(999),
            color: selected ? skin.accent.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
              color: selected ? skin.accent : skin.textSecondary.withValues(alpha: 0.35),
            ),
          ),
          child: Transform(
            transform: Matrix4.skewX(rad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],

                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        color: fg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
