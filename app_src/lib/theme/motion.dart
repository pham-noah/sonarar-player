library;

import 'package:flutter/widgets.dart';

/// The app's motion, in one place: four durations and three curves.
///
/// There used to be nine durations across two systems — this file's own nine,
/// a `Duration(milliseconds: 140)` literal inside `KitTabs`, and a
/// `tabTransitionMs` number in every theme JSON, none of them agreeing. An
/// animation is now one of four lengths (§2.6 of the audit) and one of three
/// curves, and the older names below are aliases onto them so the choreography
/// that was already written keeps working without a second set of numbers.
abstract final class Motion {
  /// A control going down: the finger already knows, so this one is short.
  static const Duration press = Duration(milliseconds: 90);

  /// A control coming back up. Slower than the press, or the release reads as a
  /// snap rather than a settle.
  static const Duration release = Duration(milliseconds: 160);

  /// A morph, a panel opening, the tab container, an art cross-fade.
  static const Duration base = Duration(milliseconds: 200);

  /// A tab change, the backdrop settling, a list arriving.
  static const Duration screen = Duration(milliseconds: 320);

  /// One item's step in a stagger. Capped at [staggerCap] items, so the whole
  /// arrival never runs past [screen].
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// How many items a stagger may carry before the tail stops waiting its turn.
  static const int staggerCap = 5;

  // ---- The names the screens already use, aliased onto the four above. ----

  /// Down.
  static const Duration pressIn = press;

  /// Up again.
  static const Duration pressOut = release;

  /// A colour or a corner changing.
  static const Duration morph = base;

  /// One cover handing over to the next inside the same frame.
  static const Duration artCrossFade = base;

  /// A sheet or a panel arriving.
  static const Duration panel = base;

  /// A whole screen of content arriving.
  static const Duration tabArrival = screen;

  /// The backdrop settling behind a new tab. It is deliberately *not* a fifth
  /// duration: it is [screen] times [backdropFactor], which is how one token
  /// still gives the two speeds the layering needs — the content lands at 320,
  /// the backdrop is still drifting at 528.
  static const double backdropFactor = 1.65;

  /// [screen] × [backdropFactor], as a duration. A `const` cannot multiply a
  /// `Duration` by a double, so the product is written out and pinned by
  /// `test/p1_tokens_test.dart`, which recomputes it from both tokens.
  static const Duration tabBackdrop = Duration(microseconds: 528000);

  /// A staggered list: [staggerCap] steps of [staggerStep], which is [screen]
  /// exactly.
  static const Duration stagger = screen;

  /// How long this animation should actually run.
  ///
  /// Android's "Remove animations" and iOS Reduce Motion both reach the app as
  /// [MediaQueryData.disableAnimations], and until now nothing read it: a user
  /// who asked the whole system to stop moving still got every transition from
  /// the 90ms press to the 528ms backdrop. Zero, not something short — a
  /// 60ms slide is still a slide, and the setting exists for people the motion
  /// itself is the problem for.
  ///
  /// Durations are constants, so this cannot happen inside them; a call site
  /// that animates says `Motion.of(context, Motion.base)` and gets the honest
  /// answer for the device it is on.
  static Duration of(BuildContext context, Duration duration) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : duration;
}

/// The three curves. `easeOutBack` is gone from the app: it overshoots, and an
/// overshoot reads as bounce at 12px and as a layout bug under a 46px headline.
abstract final class MotionCurve {
  /// Everything that moves without overshooting.
  static const Curve standard = Curves.easeOutCubic;

  /// A picture handing over to another picture, where a stop mid-way would be
  /// visible as a flash.
  static const Curve cross = Curves.easeInOut;

  /// An arrival: `easeOutCubic`, because §2.6 allows an overshoot only on type
  /// below 22px and the arrival is spent on the hero.
  static const Curve arrival = Curves.easeOutCubic;

  // ---- The names the screens already use, aliased onto the three above. ----

  static const Curve pressIn = standard;

  static const Curve pressOut = standard;

  static const Curve morph = standard;

  static const Curve art = cross;
}
