library;

import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/layout_kit.dart';
import 'pressable.dart';

double _rad(Skin skin, [double scale = 1.0]) =>
    skin.skewDegrees * (3.14159265 / 180) * scale;

class Stamp extends StatelessWidget {
  const Stamp({
    super.key,
    required this.skin,
    required this.label,
    this.icon,
    this.onTap,
    this.tooltip,
    this.inverted = false,
    this.accent = true,
  });

  final Skin skin;

  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final String? tooltip;

  final bool inverted;

  final bool accent;

  @override
  Widget build(BuildContext context) {
    final slant = _rad(skin);
    final square = slant.abs() < 0.001;

    final bg = inverted
        ? skin.background
        : (accent ? skin.accent : skin.panel);
    final fg = inverted
        ? skin.textPrimary
        : (accent ? skin.textPrimary : skin.textSecondary);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,

        borderRadius: square ? BorderRadius.circular(6) : null,
        border: square
            ? Border.all(color: skin.accentDeep.withValues(alpha: 0.5))
            : Border(
                left: BorderSide(
                  color: inverted ? skin.accent : skin.background,
                  width: 2,
                ),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            if (label != null) const SizedBox(width: 5),
          ],
          if (label != null)

            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: square ? 0.8 : 1.6,
                    color: fg,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final wrapped = Tooltip(
      message: tooltip ?? '',
      child: onTap == null
          ? chip
          : Pressable(child: InkWell(onTap: onTap, child: chip)),
    );

    return Transform(
      transform: Matrix4.skewX(-slant * 0.5),
      alignment: Alignment.center,
      child: wrapped,
    );
  }
}

class SkewPanel extends StatelessWidget {
  const SkewPanel({
    super.key,
    required this.skin,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 13, 18, 13),
    this.fill,
    this.active = false,
    this.accentEdge = true,
    this.onTap,
    this.skewScale = 0.6,
  });

  final Skin skin;
  final Widget child;
  final EdgeInsets padding;
  final Color? fill;
  final bool active;
  final bool accentEdge;
  final VoidCallback? onTap;

  final double skewScale;

  @override
  Widget build(BuildContext context) {
    final slant = _rad(skin, skewScale);
    final square = slant.abs() < 0.001;

    final body = Container(
      padding: padding,
      decoration: BoxDecoration(

        color: fill ?? (active ? skin.accent : skin.panel),
        borderRadius: square ? BorderRadius.circular(10) : null,
        border: accentEdge
            ? Border(
                left: BorderSide(
                  color: active ? skin.accent : skin.accentDeep,
                  width: 4,
                ),
              )
            : null,
      ),
      child: child,
    );

    return Transform(
      transform: Matrix4.skewX(-slant),
      alignment: Alignment.centerLeft,
      child: onTap == null
          ? body
          : Pressable(child: InkWell(onTap: onTap, child: body)),
    );
  }
}

class SectionBand extends StatelessWidget {
  const SectionBand({
    super.key,
    required this.skin,
    required this.label,
    this.trailing,
  });

  final Skin skin;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final slant = _rad(skin);
    final square = slant.abs() < 0.001;
    final form = PresentationScope.of(context, fallback: skin)
        .kit
        .chrome
        .sectionBand;

    switch (form) {
      case SectionBandForm.mark:
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
          child: Row(
            children: [
              Container(width: 3, height: 15, color: skin.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: skin.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        );

      case SectionBandForm.banner:
        return Transform(
          transform: Matrix4.skewX(-slant),
          alignment: Alignment.centerLeft,
          child: Container(
            width: double.infinity,
            color: skin.accent,
            padding: const EdgeInsets.fromLTRB(14, 5, 12, 5),
            child: Transform(
              transform: Matrix4.skewX(slant),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: square ? 0.6 : 2.4,
                        color: skin.background,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        );
    }
  }
}

class CutCorner extends StatelessWidget {
  const CutCorner({
    super.key,
    required this.skin,
    required this.child,
    this.cut = 16,
    this.fill,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  final Skin skin;
  final Widget child;

  final double cut;
  final Color? fill;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final effectiveCut = skin.skewDegrees == 0 ? 0.0 : cut;
    final body = CustomPaint(
      painter: _CutCornerPainter(
        colour: fill ?? skin.panel,
        cut: effectiveCut,
        radius: effectiveCut == 0 ? 10 : 0,
      ),
      child: Padding(padding: padding, child: child),
    );

    return onTap == null
        ? body
        : Pressable(child: InkWell(onTap: onTap, child: body));
  }
}

class _CutCornerPainter extends CustomPainter {
  _CutCornerPainter({required this.colour, required this.cut, required this.radius});

  final Color colour;
  final double cut;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = colour;
    if (radius > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        p,
      );
      return;
    }

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_CutCornerPainter old) =>
      old.colour != colour || old.cut != cut || old.radius != radius;
}

class BigNumeral extends StatelessWidget {
  const BigNumeral({
    super.key,
    required this.skin,
    required this.value,
    this.dim = false,
    this.width = 30,
  });

  final Skin skin;
  final int value;

  final bool dim;
  final double width;

  @override
  Widget build(BuildContext context) {
    final slant = _rad(skin, 0.8);
    return SizedBox(
      width: width,
      child: Transform(
        transform: Matrix4.skewX(-slant),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -0.5,
            color: dim ? skin.textSecondary : skin.accent,
          ),
          ),
        ),
      ),
    );
  }
}
