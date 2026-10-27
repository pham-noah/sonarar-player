library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/motion.dart';

enum StaggerStyle {
  shelf,

  drop,

  stamp,

  rise,
}

({double dx, double dy, double scaleFrom}) staggerGeometry(StaggerStyle style) =>
    switch (style) {
      StaggerStyle.shelf => (dx: -46.0, dy: 0.0, scaleFrom: 1.0),
      StaggerStyle.drop => (dx: 0.0, dy: -34.0, scaleFrom: 0.96),
      StaggerStyle.stamp => (dx: 0.0, dy: 0.0, scaleFrom: 0.82),
      StaggerStyle.rise => (dx: 0.0, dy: 34.0, scaleFrom: 1.0),
    };

Duration staggerStepFor(StaggerStyle style) => switch (style) {
      StaggerStyle.shelf => Motion.staggerStep,
      StaggerStyle.drop => Motion.staggerStep * 0.7,
      StaggerStyle.stamp => Motion.staggerStep * 1.25,
      StaggerStyle.rise => Motion.staggerStep * 0.85,
    };

class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.child,
    required this.index,
    this.maxIndex = 4,
    this.style = StaggerStyle.shelf,
    this.overrideDx,
    this.overrideDy,
  });

  final Widget child;

  final int index;

  final int maxIndex;

  final StaggerStyle style;

  final double? overrideDx;
  final double? overrideDy;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.stagger,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _begin();
  }

  void _begin() {
    final scrollable = Scrollable.maybeOf(context);
    final scrolling = scrollable?.position.isScrollingNotifier.value ?? false;

    final slot = widget.index.clamp(0, widget.maxIndex);
    final delay = scrolling ? Duration.zero : staggerStepFor(widget.style) * slot;

    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: MotionCurve.arrival);
    return AnimatedBuilder(
      animation: t,

      child: widget.child,
      builder: (context, child) {
        final e = t.value;
        final base = staggerGeometry(widget.style);

        final g = (
          dx: widget.overrideDx ?? base.dx,
          dy: widget.overrideDy ?? base.dy,
          scaleFrom: base.scaleFrom,
        );

        final scale = g.scaleFrom + (1 - g.scaleFrom) * e;

        if (e >= 1.0) return child!;
        return Opacity(

          opacity: (e / 0.45).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(g.dx * (1 - e), g.dy * (1 - e)),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
    );
  }
}
