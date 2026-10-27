library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'motion.dart';
import 'layout.dart';
import 'skin.dart';

enum TabMotif {
  zigzag,

  sweep,

  ripple,

  none;

  static TabMotif forTab(String tab) => switch (tab) {
        'library' => TabMotif.zigzag,
        'search' => TabMotif.sweep,
        'settings' => TabMotif.ripple,
        _ => TabMotif.none,
      };
}

enum TabArrival {
  zigzagSlant,

  sweepFromSide,

  rippleExpand,

  settle;

  static TabArrival forMotif(TabMotif motif) => switch (motif) {
        TabMotif.zigzag => TabArrival.zigzagSlant,
        TabMotif.sweep => TabArrival.sweepFromSide,
        TabMotif.ripple => TabArrival.rippleExpand,
        TabMotif.none => TabArrival.settle,
      };
}

enum TabTravel { forwards, backwards, none }

class TabArrivalView extends StatefulWidget {
  const TabArrivalView({
    super.key,
    required this.arrival,
    required this.child,
    this.travel = TabTravel.none,
    this.duration,
    this.motion,
    this.drift = 1.0,
    this.hardSnap = true,
    this.animate = true,
    this.scaleOver = 1.14,
    this.replayToken,
  });

  final double scaleOver;

  final bool animate;

  final TabArrival arrival;
  final Widget child;

  final TabTravel travel;

  final Duration? duration;

  final bool hardSnap;

  final double drift;

  final int? replayToken;

  final MotionSpec? motion;

  @override
  State<TabArrivalView> createState() => _TabArrivalViewState();
}

class _TabArrivalViewState extends State<TabArrivalView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? Motion.tabArrival,
  );

  @override
  void initState() {
    super.initState();

    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TabArrivalView old) {
    super.didUpdateWidget(old);
    if (widget.replayToken != null && widget.replayToken != old.replayToken) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) replay();
      });
    }
  }

  void replay() {
    if (!widget.animate) {
      _c.value = 1.0;
      return;
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: _c,
      curve: widget.motion?.arrivalCurve ?? MotionCurve.arrival,
    );

    return AnimatedBuilder(
      animation: t,

      child: widget.child,
      builder: (context, child) {
        final e = t.value;

        final amp = widget.motion?.arrivalAmplitude ?? 1.0;
        final rest = (1 - e) * amp;

        final dir = widget.travel == TabTravel.backwards ? -1.0 : 1.0;
        final (dx, dy) = switch (widget.arrival) {
          TabArrival.zigzagSlant => (170.0 * dir * (1 - e), 0.0),

          TabArrival.sweepFromSide => (180.0 * dir * (1 - e), 0.0),

          TabArrival.rippleExpand => (96.0 * (1 - e), -84.0 * (1 - e)),
          TabArrival.settle => (0.0, 30.0 * (1 - e)),
        };
        final scaleOvershoot = widget.scaleOver;
        final scale = 1 + (scaleOvershoot - 1) * (1 - e) * amp;

        final rotate = switch (widget.arrival) {
          TabArrival.zigzagSlant => -0.045 * dir * rest,
          TabArrival.rippleExpand => 0.030 * rest,
          _ => 0.0,
        };

        final shear = switch (widget.arrival) {
          TabArrival.zigzagSlant => math.tan(0.085) * dir * rest,

          TabArrival.sweepFromSide => math.tan(-0.075) * dir * rest,

          TabArrival.rippleExpand => math.tan(0.062) * rest,
          TabArrival.settle => 0.0,
        };

        final settleE = e * e * (3 - 2 * e);
        final snap = widget.hardSnap
            ? 1 - math.pow(1 - settleE, 2.4).toDouble()
            : e;
        final moveX = dx * widget.drift * (1 - snap) * amp;
        final moveY = dy * widget.drift * (1 - snap) * amp;

        return Transform.translate(
            offset: Offset(moveX, moveY),
            child: Transform(

              transform: Matrix4.skewY(shear),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: rotate,
                child: Transform.scale(
                  scale: scale,
                  child: RepaintBoundary(child: child),
                ),
              ),
            ),
          );
      },
    );
  }
}

class TabBackdrop extends StatelessWidget {
  const TabBackdrop({
    super.key,
    required this.skin,
    required this.motif,
  });

  final Skin skin;
  final TabMotif motif;

  @override
  Widget build(BuildContext context) {
    if (motif == TabMotif.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _MotifPainter(
          motif: motif,
          accent: skin.accent,
          deep: skin.accentDeep,
          skewDegrees: skin.skewDegrees,
        ),
      ),
    );
  }
}

class _MotifPainter extends CustomPainter {
  _MotifPainter({
    required this.motif,
    required this.accent,
    required this.deep,
    required this.skewDegrees,
  });

  final TabMotif motif;
  final Color accent;
  final Color deep;
  final double skewDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    switch (motif) {
      case TabMotif.zigzag:
        _zigzag(canvas, size);
      case TabMotif.sweep:
        _sweep(canvas, size);
      case TabMotif.ripple:
        _ripple(canvas, size);
      case TabMotif.none:
        break;
    }
  }

  void _zigzag(Canvas canvas, Size size) {
    final rad = skewDegrees * (math.pi / 180);
    final slant = math.tan(rad) * size.height;

    for (final (i, colour) in [
      (0, accent.withValues(alpha: 0.07)),
      (1, deep.withValues(alpha: 0.05)),
    ]) {
      final path = Path();

      final y0 = size.height * (0.30 + i * 0.24);
      final step = size.width * 0.34;
      path.moveTo(-slant, y0);
      for (var x = -slant; x < size.width + step; x += step) {
        path.lineTo(x + step / 2, y0 + size.height * 0.10);
        path.lineTo(x + step, y0);
      }
      path.lineTo(size.width + step, y0 + size.height * 0.16);
      for (var x = size.width + step; x > -slant; x -= step) {
        path.lineTo(x - step / 2, y0 + size.height * 0.24);
        path.lineTo(x - step, y0 + size.height * 0.14);
      }
      path.close();

      canvas.drawPath(path, Paint()..color = colour);
    }
  }

  void _sweep(Canvas canvas, Size size) {
    const count = 9;
    final paint = Paint()..color = accent.withValues(alpha: 0.08);
    final deepPaint = Paint()..color = deep.withValues(alpha: 0.06);

    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final x = size.width * (0.06 + 0.88 * t);

      final h = size.height * (0.22 + 0.34 * math.sin(t * math.pi));
      final w = i.isEven ? 2.0 : 5.0;
      canvas.drawRect(
        Rect.fromLTWH(x, size.height * 0.5 - h / 2, w, h),
        i.isEven ? paint : deepPaint,
      );
    }
  }

  void _ripple(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.92, size.height * 0.10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 1; i <= 6; i++) {
      final r = size.width * 0.10 * i;
      paint.color = accent.withValues(alpha: 0.09 / i);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: r),
        math.pi * 0.55,
        math.pi * 0.95,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MotifPainter old) =>
      old.motif != motif || old.accent != accent || old.deep != deep;
}
