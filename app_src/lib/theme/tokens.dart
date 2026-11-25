library;

import '../l10n/script.dart';
import 'package:flutter/material.dart';

import 'layout.dart';
import 'layout_kit.dart' show MaterialRadius;
import 'motion.dart';
import 'skin.dart' show LayoutSpec, Skin;

/// The numbers the UI is allowed to spend.
///
/// Every screen used to decide its own padding, corner, alpha and duration, so
/// the same relationship came out 6 here and 7 there, the same quiet text at
/// 0.55 and 0.62, and a switch could be lavender in a teal app because nothing
/// said what a switch's off state is. These are the answers, once, and the
/// component themes below spend them so a widget does not have to.
///
/// A value that is here is a decision that has been made; a value that is not
/// here is a call site's own business (a cover's aspect, a spectrum's height).
abstract final class Space {
  /// Inside a control: icon to label.
  static const double xxs = 2;

  /// Between a label and the thing it labels.
  static const double xs = 4;

  /// Between rows in a group.
  static const double sm = 8;

  /// Between a group and the next group's heading.
  static const double md = 12;

  /// Inside a panel that holds rows.
  static const double lg = 16;

  /// Screen edge, and the gap under a header.
  static const double xl = 24;

  /// Between the bands of a screen.
  static const double xxl = 32;

  /// A band's own breathing room.
  static const double xxxl = 48;

  /// Android's minimum touch target. Nothing tappable is smaller than this,
  /// which is the whole of P0-2: four controls were 34, 34, 44 and 44.
  static const double tap = 48;
}

abstract final class Corners {
  /// A plate with a heavy left edge: the slab, the banner.
  static const double none = 0;

  /// `r-sm` — inline chips, badges, the accent tick.
  static const double sm = 4;

  /// `r-md` — rows, cards, buttons, cover art, and the default every surface
  /// falls back to when its theme declares no radius of its own.
  static const double md = MaterialRadius.defaultRadius;

  /// `r-lg` — a sheet's top corners, a floating panel.
  static const double lg = 24;

  /// A pill: the tab capsule, a chip that wraps a single word.
  static const double pill = 999;
}

/// The type ladder: seven steps, each one a job, not a size someone liked.
///
/// Fourteen sizes were in use, six of them between 13 and 19 — inside the range
/// where a one-pixel difference is noise rather than hierarchy. The weight
/// ladder matters as much as the sizes: 197 of 198 declarations were w600 or
/// heavier, so every row label, value and note competed at the same density.
/// Display, hero and title are w900; caps labels and values w800; row labels
/// w700; body and notes w400.
abstract final class Type {
  static TextStyle _style(
    BuildContext context, {
    required double size,
    required double height,
    required FontWeight weight,
    double tracking = 0,
    Color? color,
  }) =>
      TextStyle(
        fontSize: size,
        height: height,
        fontWeight: weight,
        letterSpacing: tracking == 0 ? null : trackingFor(context, tracking),
        color: color,
      );

  /// A screen's one heading: SETTINGS, LIBRARY.
  static TextStyle display(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontTitle,
      height: 1.05,
      weight: FontWeight.w900,
      tracking: -0.4,
      color: color);

  /// The greeting on Home.
  static TextStyle hero(BuildContext c, {Color? color}) => _style(c,
      size: 46,
      height: 1.02,
      weight: FontWeight.w900,
      tracking: -0.6,
      color: color);

  /// A player's track title, a sheet's title.
  static TextStyle title(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontBase,
      height: 1.15,
      weight: FontWeight.w900,
      color: color);

  /// Pitch text, empty-state body: the one weight the app never used.
  static TextStyle body(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontSmall,
      height: 1.35,
      weight: FontWeight.w400,
      color: color);

  /// Notes and descriptions.
  static TextStyle bodyBase(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontFloor,
      height: 1.35,
      weight: FontWeight.w400,
      color: color);

  /// A settings row's label, a list row's secondary line.
  static TextStyle row(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontRow, height: 1.2, weight: FontWeight.w700, color: color);

  /// Caps eyebrows, badges, durations, and every value in a row.
  static TextStyle micro(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontMicro,
      height: 1.2,
      weight: FontWeight.w800,
      tracking: 0.8,
      color: color);

  /// A caps label that has to be found: section marks, tab labels.
  static TextStyle caps(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontRow,
      height: 1.2,
      weight: FontWeight.w800,
      tracking: 0.8,
      color: color);

  /// The same caps label where the surface has a 16px floor of its own.
  ///
  /// Home carries a standing rule — `test/home_sections_test.dart` — that
  /// nothing on it renders below `fontFloor`; its band and state labels are the
  /// ones a person reads while walking, so they keep the caps weight and
  /// tracking but not the 14px size.
  static TextStyle capsFloor(BuildContext c, {Color? color}) => _style(c,
      size: LayoutSpec.fontFloor,
      height: 1.2,
      weight: FontWeight.w800,
      tracking: 0.8,
      color: color);

  // Weights, so a row label and a heading cannot drift apart.
  static const FontWeight heavy = FontWeight.w900;
  static const FontWeight strong = FontWeight.w800;
  static const FontWeight label = FontWeight.w700;
  static const FontWeight regular = FontWeight.w400;

  /// Line height for anything that can wrap to two lines.
  static const double readable = 1.35;
}

/// How much of a colour a state is allowed.
///
/// The app had ten different alphas for "quiet text", decided per call site.
/// These are the ones that mean something, so a disabled control and a note no
/// longer disagree about what quiet is.
///
/// Named `Tone` rather than `Opacity` so it cannot shadow Flutter's `Opacity`
/// widget in a file that imports both.
abstract final class Tone {
  /// A hairline, a scrim's edge.
  static const double hairline = 0.12;

  /// Structure you should feel and not read: a border, a divider.
  static const double edge = 0.28;

  /// Text that supports, but is not the point. Floored per theme by
  /// `Skin.secondary`, so this is a wish rather than a guarantee.
  static const double quiet = 0.62;

  /// Text that is almost the point.
  static const double soft = 0.82;

  /// A disabled control's ink, measured against its own track.
  static const double disabled = 0.38;
}

abstract final class StateLayer {
  /// A pointer resting on something it could press.
  static const double hover = 0.08;

  /// Keyboard focus: the loudest of the three, because it is the only one a
  /// person navigating without a mouse can see.
  static const double focus = 0.16;

  /// A finger on the control.
  static const double pressed = 0.20;

  /// A drag, which outranks a press.
  static const double dragged = 0.24;
}

/// Depth, as one decision per level (§2.5).
///
/// A shadow is not depth on a near-black page: `#000` at 45% drawn on a
/// background that is itself near-black measures about 1:1, i.e. nothing, which
/// is why the app's plates used to sit on the page with no edge at all. On dark
/// the lift is a *rim* — a 1px light line along the top of the plate — plus a
/// real drop shadow; on light it is the drop shadow alone.
///
/// The rim is drawn as a zero-blur shadow offset one pixel up, which is the
/// only way a `BoxShadow` can paint an inner highlight: an inset shadow does not
/// exist in Flutter, and a border would have to be four sides of the box.
abstract final class Elevation {
  /// The rim light a dark plate gets: 1px, white at 10%, at the top edge.
  static const BoxShadow rim = BoxShadow(
    color: Color(0x1AFFFFFF),
    offset: Offset(0, -1),
  );

  /// `e0` — flat on the page. A row inside a group.
  static const List<BoxShadow> e0 = <BoxShadow>[];

  /// `e1` — a plate. Delimited by a `borderStrong` 1px edge; on dark that edge
  /// is the whole of the depth, on light it carries a 1px soft shadow too.
  static List<BoxShadow> e1({required bool light}) => light
      ? const <BoxShadow>[
          BoxShadow(color: Color(0x0F1D1A16), blurRadius: 2, offset: Offset(0, 1)),
        ]
      : e0;

  /// `e2` — anything floating over content: the mini player, the CTA.
  static List<BoxShadow> e2({required bool light}) => light
      ? const <BoxShadow>[
          BoxShadow(color: Color(0x1A1D1A16), blurRadius: 6, offset: Offset(0, 2)),
        ]
      : const <BoxShadow>[
          rim,
          BoxShadow(color: Color(0x73000000), blurRadius: 20, offset: Offset(0, 6)),
        ];

  /// `e3` — an overlay: a sheet, the player panel.
  static List<BoxShadow> e3({required bool light}) => light
      ? const <BoxShadow>[
          BoxShadow(color: Color(0x241D1A16), blurRadius: 24, offset: Offset(0, 8)),
        ]
      : const <BoxShadow>[
          rim,
          BoxShadow(color: Color(0x8C000000), blurRadius: 32, offset: Offset(0, 12)),
        ];

  /// The edge `e1` draws where a shadow cannot be seen at all.
  static Border edge(Skin skin) => Border.all(color: skin.borderStrong);
}

/// The four durations a state change is allowed, in the vocabulary a
/// `ThemeData` can carry. The values live in `Motion`.
abstract final class StateMotion {
  /// A press lands immediately and leaves slowly: the finger already knows.
  static const Duration pressIn = Motion.press;
  static const Duration pressOut = Motion.release;

  /// A colour or a corner changing under a pointer.
  static const Duration settle = Motion.base;

  /// A sheet or a panel arriving.
  static const Duration panel = Motion.base;
}

/// The two states of a switch, in one theme's colours.
///
/// OFF used to be louder than ON: the inactive track fell back to Material's
/// outline (21:1 on Abyss) while the active track was a 2.32:1 accent wash, and
/// on Minimal the knob vanished into its own track. Now ON is the accent
/// surface with `onAccent` on it, OFF is the theme's control edge with muted
/// ink, and neither state draws a ring — the outline was the loud part.
@immutable
class SwitchInk {
  const SwitchInk({
    required this.on,
    required this.onContent,
    required this.off,
    required this.offContent,
  });

  factory SwitchInk.ofSkin(Skin skin) => SwitchInk(
        on: skin.accent,
        onContent: skin.onAccent,
        off: skin.borderStrong,
        offContent: skin.textMuted,
      );

  factory SwitchInk.ofPalette(LayoutPalette palette) => SwitchInk(
        on: palette.accent,
        onContent: palette.onAccent,
        off: palette.borderStrong,
        offContent: palette.textMuted,
      );

  final Color on;
  final Color onContent;
  final Color off;
  final Color offContent;

  /// How much of its colour a switch keeps when it cannot be operated.
  ///
  /// Material dims a disabled switch on Cupertino only; on Android a gated row's
  /// switch drew in full contrast with a live-looking knob, so WEATHER VARIANTS
  /// under a WEATHER that was off offered a control that did nothing. Half
  /// strength, resolved here, is the state — not something the call site does.
  static const double disabledStrength = 0.45;

  static WidgetStateProperty<Color> _picked(Color on, Color off) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          final base = states.contains(WidgetState.selected) ? on : off;
          return base.withValues(alpha: base.a * disabledStrength);
        }
        return states.contains(WidgetState.selected) ? on : off;
      });

  WidgetStateProperty<Color> get track => _picked(on, off);

  WidgetStateProperty<Color> get thumb => _picked(onContent, offContent);

  /// No ring, in either state: the fill carries the state.
  WidgetStateProperty<Color> get outline =>
      WidgetStateProperty.resolveWith((_) => Colors.transparent);

  SwitchThemeData get themeData => SwitchThemeData(
        trackColor: track,
        thumbColor: thumb,
        trackOutlineColor: outline,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return on.withValues(alpha: StateLayer.pressed);
          }
          if (states.contains(WidgetState.focused)) {
            return on.withValues(alpha: StateLayer.focus);
          }
          if (states.contains(WidgetState.hovered)) {
            return on.withValues(alpha: StateLayer.hover);
          }
          return Colors.transparent;
        }),
      );
}

/// The component themes, built from one palette.
///
/// Anything Material draws for us — a switch, an ink splash, a focus ring, a
/// disabled ink — is decided here rather than at each call site, so a control
/// cannot be the one lavender thing in a teal screen.
abstract final class ComponentTheme {
  /// Every switch the app draws, in this palette's two states.
  static SwitchThemeData switches(LayoutPalette pal) =>
      SwitchInk.ofPalette(pal).themeData;

  /// The colour an ink response paints for each of the states a pointer can put
  /// it in. Before this, an ink splash on a dark panel was a white wash at an
  /// alpha Material picked, and a keyboard focus changed nothing at all.
  static Color inkColor(LayoutPalette pal, Set<WidgetState> state) {
    if (state.contains(WidgetState.pressed)) {
      return pal.accent.withValues(alpha: StateLayer.pressed);
    }
    if (state.contains(WidgetState.focused)) {
      return pal.accent.withValues(alpha: StateLayer.focus);
    }
    if (state.contains(WidgetState.hovered)) {
      return pal.accent.withValues(alpha: StateLayer.hover);
    }
    return pal.accent.withValues(alpha: 0);
  }
}

/// The `ThemeData` fields that carry the tokens above.
///
/// Kept beside `themeFor` rather than in it: the palette decides the colours,
/// this decides what a control does with them.
ThemeData applyTokens(ThemeData theme, LayoutPalette palette) {
  return theme.copyWith(
    switchTheme: ComponentTheme.switches(palette),
    splashColor: palette.accent.withValues(alpha: StateLayer.pressed),
    highlightColor: palette.accent.withValues(alpha: StateLayer.pressed),
    hoverColor: palette.accent.withValues(alpha: StateLayer.hover),
    focusColor: palette.accent.withValues(alpha: StateLayer.focus),
    iconTheme: theme.iconTheme.copyWith(
      color: palette.textPrimary,
    ),
    dividerTheme: theme.dividerTheme.copyWith(
      color: palette.border.withValues(alpha: Tone.edge),
      thickness: 1,
    ),
  );
}
