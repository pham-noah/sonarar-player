library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'layout_kit.dart';

enum SurfaceRole { panel, card, bar, sheet }

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.presentation,
    this.role = SurfaceRole.panel,
    this.fill,
    this.border,
    this.accentEdge = false,
    this.active = false,
    this.radius,
    this.padding,
    this.child,
  });

  final Presentation presentation;
  final SurfaceRole role;

  final Color? fill;

  final Border? border;

  final bool accentEdge;

  final bool active;

  final double? radius;
  final EdgeInsetsGeometry? padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = presentation;
    final pal = p.palette;
    final mat = p.kit.material;

    final skew = p.skewDegrees;
    final rad = skew * (3.14159265 / 180);

    final resolvedRadius = radius ?? mat.radii[role] ?? 4.0;
    final resolvedPadding = padding ?? EdgeInsets.zero;

    final baseFill =
        fill ?? (active && mat.activeFillIsAccent ? pal.accent : pal.surface);

    final content = Container(
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: isGlassMaterial(mat)
            ? _glassTint(pal, role, baseFill)
            : baseFill,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: border ?? _borderFor(pal, mat, active),
        boxShadow: _shadowFor(pal, role, mat),
      ),

      child: skew == 0
          ? child
          : Transform(
              transform: Matrix4.skewX(-rad),
              alignment: Alignment.centerLeft,
              child: child,
            ),
    );

    final body = skew == 0
        ? content
        : Transform(
            transform: Matrix4.skewX(rad),
            alignment: Alignment.centerLeft,
            child: content,
          );

    if (!isGlassMaterial(mat)) {
      return body;
    }

    return _glassBody(resolvedRadius, body, pal);
  }

  static bool isGlassMaterial(MaterialKit mat) => mat.blur > 0;

  static Border _borderFor(LayoutPalette pal, MaterialKit mat, bool active) {
    if (mat.edge == SurfaceEdge.heavy) {
      return Border(
        left: BorderSide(
          color: active ? pal.onAccent : pal.accentDeep,
          width: 5,
        ),
      );
    }
    return Border.all(
      color: active && mat.activeFillIsAccent ? pal.accent : pal.border,
      width: 1,
    );
  }

  static List<double> _saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final inv = 1.0 - s;
    return <double>[
      inv * lr + s,
      inv * lg,
      inv * lb,
      0,
      0,
      inv * lr,
      inv * lg + s,
      inv * lb,
      0,
      0,
      inv * lr,
      inv * lg,
      inv * lb + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  static Widget _glassBody(
    double resolvedRadius,
    Widget body,
    LayoutPalette pal,
  ) {
    final content = Stack(
      fit: StackFit.passthrough,
      children: [
        body,

        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 1.5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    pal.border.withValues(alpha: 0.0),

                    pal.textPrimary.withValues(alpha: 0.42),
                    pal.border.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 1.5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    pal.border.withValues(alpha: 0.0),

                    pal.textPrimary.withValues(alpha: 0.16),
                    pal.border.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 1.5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    pal.border.withValues(alpha: 0.0),
                    pal.textPrimary.withValues(alpha: 0.62),
                    pal.textPrimary.withValues(alpha: 0.34),
                    pal.border.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 1.5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    pal.border.withValues(alpha: 0.0),
                    pal.textPrimary.withValues(alpha: 0.34),
                    pal.textPrimary.withValues(alpha: 0.62),
                    pal.border.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(resolvedRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.compose(
          outer: ui.ColorFilter.matrix(_saturationMatrix(1.8)),
          inner: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        ),
        child: content,
      ),
    );
  }

  /// The tint a glass surface actually paints, for a test that wants to reason
  /// about legibility without a screenshot.
  @visibleForTesting
  static Color glassTintFor(
    LayoutPalette pal,
    SurfaceRole role,
    Color baseFill,
  ) => Surface._glassTint(pal, role, baseFill);

  static Color _glassTint(LayoutPalette pal, SurfaceRole role, Color baseFill) {
    final a = baseFill.a;

    final strength = switch (role) {
      SurfaceRole.bar => 1.0,
      SurfaceRole.card => 1.0,
      SurfaceRole.panel => 1.0,
      SurfaceRole.sheet => 1.0,
    };

    // A panel is read, not looked through. At the palette's own alpha whatever is
    // behind it — a bright cover, the player's own controls — was still there to read
    // through the text. Bars and cards are small enough to stay glassy; a sheet that
    // covers half the screen has to hold its own colour.
    final floor = switch (role) {
      SurfaceRole.panel => 0.96,
      _ => 0.0,
    };

    // Glass paints a wash — in the Glass palettes `surface` is white at 20% — and a
    // wash is only legible while the room under it is dark. Over a bright cover the
    // sheet went pale and the text, which is near-white, disappeared into it. So the
    // sheet carries the room's colour: the wash over `background`, held at the floor.
    // A bar or a card is small and sits on something known; a sheet is read over
    // whatever is behind it.
    final base = role == SurfaceRole.panel
        ? Color.alphaBlend(baseFill, pal.background)
        : baseFill;

    return base.withValues(alpha: (a * strength).clamp(floor, 1.0));
  }

  static List<BoxShadow> _shadowFor(
    LayoutPalette pal,
    SurfaceRole role,
    MaterialKit mat,
  ) {
    if (isGlassMaterial(mat)) {
      return const [
        BoxShadow(
          color: Color(0x59000000),
          blurRadius: 28,
          offset: Offset(0, 8),
        ),
      ];
    }
    if (pal.shadow.a == 0) return const [];
    if (mat.castShadow && !isGlassMaterial(mat) && mat.slant) {
      return [
        BoxShadow(
          color: pal.shadow,
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
      ];
    }
    final blur = switch (role) {
      SurfaceRole.bar => 26.0,
      SurfaceRole.sheet => 34.0,
      SurfaceRole.card => 14.0,
      SurfaceRole.panel => 22.0,
    };
    return [
      BoxShadow(
        color: pal.shadow,
        blurRadius: blur,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
