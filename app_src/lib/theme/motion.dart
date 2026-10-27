library;

import 'package:flutter/animation.dart';

abstract final class Motion {
  static const Duration press = Duration(milliseconds: 55);

  static const Duration release = Duration(milliseconds: 220);

  static const Duration morph = Duration(milliseconds: 180);

  static const Duration artCrossFade = Duration(milliseconds: 240);

  static const Duration panel = Duration(milliseconds: 220);

  static const Duration tabArrival = Duration(milliseconds: 260);

  static const Duration tabBackdrop = Duration(milliseconds: 430);

  static const Duration stagger = Duration(milliseconds: 300);

  static const Duration staggerStep = Duration(milliseconds: 42);
}

abstract final class MotionCurve {
  static const Curve pressIn = Curves.easeOutCubic;

  static const Curve pressOut = Curves.easeOutBack;

  static const Curve morph = Curves.easeOutCubic;

  static const Curve art = Curves.easeInOut;

  static const Curve arrival = Curves.easeOutBack;
}
