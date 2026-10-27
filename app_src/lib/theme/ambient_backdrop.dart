library;

import 'package:flutter/material.dart';

import 'layout.dart';

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({
    super.key,
    required this.presentation,
    this.strength = 1.0,
  });

  final Presentation presentation;

  final double strength;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AmbientPainter(
        base: presentation.palette.background,
        accents: presentation.palette.ambient,
        strength: strength,
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.base,
    required this.accents,
    required this.strength,
  });

  final Color base;

  final List<Color> accents;

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
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
