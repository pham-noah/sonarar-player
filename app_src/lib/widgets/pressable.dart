import 'package:flutter/material.dart';

import '../theme/motion.dart';

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.pressedScale = 0.88,
    this.onTap,
  });

  final Widget child;

  final VoidCallback? onTap;

  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) {
        if (_down) widget.onTap?.call();
        _set(false);
      },

      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,

        duration: _down ? Motion.press : Motion.release,
        curve: _down ? MotionCurve.pressIn : MotionCurve.pressOut,
        child: widget.child,
      ),
    );
  }
}
