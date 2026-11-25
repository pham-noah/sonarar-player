library;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

class CrossFadeSlot extends StatelessWidget {
  const CrossFadeSlot({
    super.key,
    required this.keyValue,
    required this.child,
    this.duration,
  });

  final Object keyValue;

  final Widget child;
  /// Null means "as long as an art cross-fade should take on this device" —
  /// resolved in [build] because a const default cannot ask whether the user
  /// turned animations off.
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, duration ?? Motion.artCrossFade),
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
