library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'personalization.dart';

/// The background when there is no photo: one colour, or two in a gradient.
/// It sits where the skin's flat base would, so a themed app without a picture
/// still has a deliberate surface instead of a default one.
class FillBackdrop extends StatelessWidget {
  const FillBackdrop({super.key, required this.fill});

  final BackdropFill fill;

  static Alignment _dir(double degrees) {
    final rad = degrees * 3.141592653589793 / 180;
    // A zero-length vector is what BoxDecoration rejects; nudge it.
    final dx = _cos(rad);
    final dy = _sin(rad);
    return Alignment(dx.abs() < 0.0001 ? 0.0001 : dx, dy.abs() < 0.0001 ? 0.0001 : dy);
  }

  static double _cos(double v) => _sin(v + 3.141592653589793 / 2);
  static double _sin(double v) {
    // Small, exact-enough sin to avoid a dart:math import in this file's hot path.
    var x = v % (2 * 3.141592653589793);
    if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    final x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120 - x2 * x2 * x2 / 5040);
  }

  @override
  Widget build(BuildContext context) {
    if (!fill.isSet) return const SizedBox.shrink();
    final start = Color(fill.start ?? 0xFF0E0E12);
    final end = Color(fill.end ?? fill.start ?? 0xFF0E0E12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill.isGradient ? null : start,
        gradient: fill.isGradient
            ? LinearGradient(
                begin: _dir(fill.angle),
                end: _dir(fill.angle + 180),
                colors: [start, end],
              )
            : null,
      ),
    );
  }
}

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    super.key,
    required this.presentation,
    this.strength = 1.0,
    this.transparent = false,
  });

  final Presentation presentation;

  final double strength;

  /// Skip the flat base colour, so a photo underneath is what shows through.
  /// The accent spots still paint, which is what keeps the skin present.
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AmbientPainter(
        base: presentation.palette.background,
        accents: presentation.palette.ambient,
        strength: strength,
        transparent: transparent,
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.base,
    required this.accents,
    required this.strength,
    required this.transparent,
  });

  final Color base;

  final List<Color> accents;

  final double strength;

  final bool transparent;

  @override
  void paint(Canvas canvas, Size size) {
    if (!transparent) canvas.drawRect(Offset.zero & size, Paint()..color = base);
    if (accents.isEmpty || strength <= 0) return;

    const spots = <({double x, double y, double rx, double ry})>[
      (x: 0.06, y: 0.02, rx: 0.85, ry: 0.38),
      (x: 1.00, y: 0.34, rx: 0.75, ry: 0.36),
      (x: 0.14, y: 0.78, rx: 0.90, ry: 0.42),
      (x: 0.96, y: 1.00, rx: 0.70, ry: 0.30),
    ];

    for (var i = 0; i < spots.length && i < accents.length; i++) {
      final s = spots[i];
      final c = accents[i];
      final centre = Offset(s.x * size.width, s.y * size.height);
      final radius = (s.rx * size.width + s.ry * size.height) / 2;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            c.withValues(alpha: c.a * strength),
            c.withValues(alpha: 0),
          ],

          stops: const [0.0, 0.7],
        ).createShader(Rect.fromCircle(center: centre, radius: radius));
      canvas.drawCircle(centre, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.base != base ||
      old.strength != strength ||
      !identical(old.accents, accents);
}
