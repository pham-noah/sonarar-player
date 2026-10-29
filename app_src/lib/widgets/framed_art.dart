library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../art/art_focus.dart';
import '../art/art_spec.dart';

class FramedArt extends StatelessWidget {
  const FramedArt({
    super.key,
    required this.assetPath,
    required this.aspect,
    required this.focus,
    this.cacheWidth,
    this.enterFrom,
    this.opacity = 1.0,
    this.burn = 0.0,
    this.spec = ArtSpec.none,
  });

  final String assetPath;

  final double aspect;

  final ArtFocus focus;

  final int? cacheWidth;

  final double? enterFrom;

  final double opacity;

  /// How far the art's edges dissolve into what is behind it, 0..1.
  ///
  /// A cut edge is a rectangle; the burn is what makes the picture sit in the
  /// room instead of on top of it. It is a mask, not a painted overlay: an
  /// overlay darkens the middle of the picture too, which is a different look.
  final double burn;

  /// How the picture is placed by the art editor. The default is untouched, so
  /// every existing caller keeps framing exactly as it did.
  final ArtSpec spec;

  @override
  Widget build(BuildContext context) {
    final framed = RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotW = constraints.maxWidth;
          final slotH = constraints.maxHeight;
          if (slotW <= 0 || slotH <= 0) return const SizedBox.shrink();

          final frame = frameFor(
            srcW: aspect,
            srcH: 1.0,
            slotW: slotW,
            slotH: slotH,
            focus: focus,
          );

          final drawnW = aspect * frame.scale;
          final drawnH = frame.scale;

          // The dissolve follows the framing, so the part the user centred stays
          // solid wherever they put it.
          final centre = Alignment(
            (focus.dx * 0.8).clamp(-1.0, 1.0) + 0.15,
            (-focus.dy * 0.8).clamp(-1.0, 1.0) - 0.10,
          );

          Widget mask(Widget child) {
            if (burn <= 0) return child;
            final solid = (1.0 - 0.28 * burn).clamp(0.0, 1.0);
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => RadialGradient(
                center: centre,
                radius: 1.05,
                colors: [
                  Colors.black.withValues(alpha: solid),
                  Colors.black.withValues(alpha: solid * 0.72),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.62, 1.0],
              ).createShader(rect),
              child: child,
            );
          }

          final place = spec.place(slotW, slotH);

          return mask(
            ClipRect(
              child: OverflowBox(
                alignment: Alignment.center,
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                child: Transform.translate(
                  offset: Offset(
                    frame.offsetX + place.tx,
                    frame.offsetY + place.ty,
                  ),
                  child: Transform.rotate(
                    angle: place.angle,
                    child: Transform.scale(
                      scale: place.scale,
                      child: Transform.flip(
                        flipX: spec.flipX,
                        child: SizedBox(
                          width: drawnW,
                          height: drawnH,
                          // `file:` marks a picture the user supplied; everything else is
                          // a shipped asset. Same framing either way.
                          child: assetPath.startsWith('file:')
                              ? Image.file(
                                  File(assetPath.substring(5)),
                                  opacity: opacity == 1.0
                                      ? null
                                      : AlwaysStoppedAnimation<double>(opacity),
                                  fit: BoxFit.fill,
                                  cacheWidth: cacheWidth,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : Image.asset(
                                  assetPath,
                                  opacity: opacity == 1.0
                                      ? null
                                      : AlwaysStoppedAnimation<double>(opacity),
                                  fit: BoxFit.fill,
                                  cacheWidth: cacheWidth,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final from = enterFrom;
    if (from == null) return framed;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: 0.0),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutBack,
      builder: (context, dx, child) =>
          Transform.translate(offset: Offset(dx, 0), child: child),
      child: framed,
    );
  }
}
