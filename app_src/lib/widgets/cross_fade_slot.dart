library;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

class CrossFadeSlot extends StatelessWidget {
  const CrossFadeSlot({
    super.key,
    required this.keyValue,
    required this.child,
    this.duration = Motion.artCrossFade,
  });

  final Object keyValue;

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: MotionCurve.art,
      switchOutCurve: MotionCurve.art,

      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,

        child: child,
      ),
      child: KeyedSubtree(key: ValueKey<Object>(keyValue), child: child),
    );
  }
}
