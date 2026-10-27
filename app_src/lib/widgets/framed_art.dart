library;

import 'package:flutter/material.dart';

import '../art/art_focus.dart';

class FramedArt extends StatelessWidget {
  const FramedArt({
    super.key,
    required this.assetPath,
    required this.aspect,
    required this.focus,
    this.cacheWidth,
    this.enterFrom,
    this.opacity = 1.0,
  });

  final String assetPath;

  final double aspect;

  final ArtFocus focus;

  final int? cacheWidth;

  final double? enterFrom;

  final double opacity;

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

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(frame.offsetX, frame.offsetY),
              child: SizedBox(
                width: drawnW,
                height: drawnH,
                child: Image.asset(
                  assetPath,

                  opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation<double>(opacity),

                  fit: BoxFit.fill,
                  cacheWidth: cacheWidth,

                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
