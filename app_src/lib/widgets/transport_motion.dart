library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/motion.dart';

const double kTransportNudge = 6.0;

class NudgingButton extends StatefulWidget {
  const NudgingButton({
    super.key,
    required this.direction,
    required this.child,
    this.onTap,
  });

  final int direction;

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<NudgingButton> createState() => _NudgingButtonState();
}

class _NudgingButtonState extends State<NudgingButton> {
  int _tick = 0;

  void _tap() {
    if (widget.onTap == null) return;
    if (widget.direction != 0) setState(() => _tick++);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null || widget.direction == 0) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: TweenAnimationBuilder<double>(

        key: ValueKey<int>(_tick),

        tween: Tween<double>(
          begin: kTransportNudge * widget.direction,
          end: 0.0,
        ),
        duration: Motion.morph,
        curve: MotionCurve.morph,
        builder: (context, dx, child) =>
            Transform.translate(offset: Offset(dx, 0), child: child),
        child: widget.child,
      ),
    );
  }
}

class PopOnChange extends StatefulWidget {
  const PopOnChange({
    super.key,
    required this.keyValue,
    required this.child,
  });

  final Object keyValue;

  final Widget child;

  @override
  State<PopOnChange> createState() => _PopOnChangeState();
}

class _PopOnChangeState extends State<PopOnChange> {
  int _tick = 0;

  @override
  void didUpdateWidget(PopOnChange old) {
    super.didUpdateWidget(old);
    if (old.keyValue != widget.keyValue) setState(() => _tick++);
  }

  @override
  Widget build(BuildContext context) {
    if (_tick == 0) return widget.child;
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_tick),
      tween: Tween<double>(begin: 0.90, end: 1.0),
      duration: Motion.release,

      curve: MotionCurve.pressOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: widget.child,
    );
  }
}

class SwapSlide extends StatefulWidget {
  const SwapSlide({
    super.key,
    required this.keyValue,
    required this.child,
    this.stagger = Duration.zero,
  });

  final Object keyValue;

  final Widget child;

  final Duration stagger;

  @override
  State<SwapSlide> createState() => _SwapSlideState();
}

class _SwapSlideState extends State<SwapSlide> {
  bool _in = true;

  @override
  void didUpdateWidget(SwapSlide old) {
    super.didUpdateWidget(old);
    if (old.keyValue == widget.keyValue) return;

    setState(() => _in = false);

    _staggerTimer?.cancel();
    _staggerTimer = Timer(widget.stagger, () {
      if (mounted) setState(() => _in = true);
    });
  }

  Timer? _staggerTimer;

  @override
  void dispose() {
    _staggerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _in ? Offset.zero : const Offset(0, 0.22),
      duration: Motion.morph,
      curve: MotionCurve.morph,
      child: AnimatedOpacity(
        opacity: _in ? 1.0 : 0.0,
        duration: Motion.morph,
        curve: MotionCurve.morph,
        child: widget.child,
      ),
    );
  }
}
