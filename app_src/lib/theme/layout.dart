library;

import 'package:flutter/material.dart';

import 'layout_kit.dart';
import 'motion.dart';
import 'skin.dart';

enum LayoutKind {
  sonar,

  solid,

  glass;

  LayoutKit get kit => switch (this) {
        LayoutKind.sonar => LayoutKit.sonar,
        LayoutKind.solid => kSolidKit,
        LayoutKind.glass => kGlassKit,
      };
}

enum MaterialStyle {
  flat,

  glass,
}

@immutable
class LayoutPalette {
  const LayoutPalette({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.border,
    required this.shadow,
    this.ambient = const [],
    this.pageFill,
  });

  factory LayoutPalette.fromSkin(Skin skin) => LayoutPalette(
        background: skin.background,
        surface: skin.panel,
        textPrimary: skin.textPrimary,
        textSecondary: skin.textSecondary,
        accent: skin.accent,
        accentDeep: skin.accentDeep,
        onAccent: skin.onAccent,
        border: skin.textSecondary.withValues(alpha: 0.35),
        shadow: skin.slabShadow,
      );

  final Color background;

  final Color surface;

  final Color textPrimary;
  final Color textSecondary;

  final Color accent;
  final Color accentDeep;
  final Color onAccent;

  final Color border;

  final Color shadow;

  final List<Color> ambient;

  final Color? pageFill;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutPalette &&
          runtimeType == other.runtimeType &&
          background == other.background &&
          surface == other.surface &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          accent == other.accent &&
          accentDeep == other.accentDeep &&
          onAccent == other.onAccent &&
          border == other.border &&
          shadow == other.shadow &&
          ambient == other.ambient &&
          pageFill == other.pageFill;

  @override
  int get hashCode => Object.hash(
        background,
        surface,
        textPrimary,
        textSecondary,
        accent,
        accentDeep,
        onAccent,
        border,
        shadow,
        Object.hashAllUnordered(ambient),
        pageFill,
      );
}

@immutable
class MotionSpec {
  const MotionSpec({
    required this.tabTransition,
    this.arrivalCurve = MotionCurve.arrival,
    this.arrivalAmplitude = 1.0,
    this.backdropFactor = 1.65,
    this.enabled = true,
  });

  final Duration tabTransition;

  final Curve arrivalCurve;
  final double arrivalAmplitude;

  final double backdropFactor;

  final bool enabled;

  static const MotionSpec persona = MotionSpec(
    tabTransition: Duration(milliseconds: 420),
  );

  static const MotionSpec restrained = MotionSpec(
    tabTransition: Duration(milliseconds: 260),
    arrivalCurve: Curves.easeOutCubic,
    arrivalAmplitude: 0.5,
    backdropFactor: 1.4,
  );
}

@immutable
class ScreenLayout {
  const ScreenLayout({
    required this.libraryIsGrid,
    required this.headerScrollsAway,
    required this.contextPlateExists,
    required this.tabBarIsFloating,
    required this.tabBarInsets,
    this.contentMaxWidth,
  });

  static const ScreenLayout persona = ScreenLayout(
    libraryIsGrid: false,
    headerScrollsAway: false,
    contextPlateExists: true,
    tabBarIsFloating: false,
    tabBarInsets: EdgeInsets.zero,
  );

  static const ScreenLayout plain = ScreenLayout(
    libraryIsGrid: true,
    headerScrollsAway: true,
    contextPlateExists: false,
    tabBarIsFloating: true,
    tabBarInsets: EdgeInsets.fromLTRB(12, 0, 12, 10),
    contentMaxWidth: 720,
  );

  final bool libraryIsGrid;

  final bool headerScrollsAway;

  final bool contextPlateExists;

  final bool tabBarIsFloating;

  final EdgeInsets tabBarInsets;

  bool get miniPlayerIsFloating => tabBarIsFloating;

  double get bottomClearance =>
      LayoutSpec.tabBarHeight +
      LayoutSpec.miniPlayerHeight +
      tabBarInsets.bottom;

  final double? contentMaxWidth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenLayout &&
          runtimeType == other.runtimeType &&
          libraryIsGrid == other.libraryIsGrid &&
          headerScrollsAway == other.headerScrollsAway &&
          contextPlateExists == other.contextPlateExists &&
          tabBarIsFloating == other.tabBarIsFloating &&
          tabBarInsets == other.tabBarInsets &&
          contentMaxWidth == other.contentMaxWidth;

  @override
  int get hashCode => Object.hash(
        libraryIsGrid,
        headerScrollsAway,
        contextPlateExists,
        tabBarIsFloating,
        tabBarInsets,
        contentMaxWidth,
      );
}

@immutable
class Presentation {
  const Presentation({
    required this.layout,
    required this.palette,
    required this.material,
    required this.motion,
    required this.arrangement,
    required this.kit,
    this.skewDegrees = 0.0,
  });

  factory Presentation.forSkin(Skin skin) => Presentation(
        layout: LayoutKind.sonar,
        palette: LayoutPalette.fromSkin(skin),
        material: MaterialStyle.flat,
        motion: MotionSpec.persona,
        arrangement: ScreenLayout.persona,
        kit: LayoutKit.sonar,
        skewDegrees: skin.skewDegrees,
      );

  final LayoutKind layout;
  final LayoutPalette palette;
  final MaterialStyle material;
  final MotionSpec motion;
  final ScreenLayout arrangement;

  final LayoutKit kit;

  final double skewDegrees;

  bool get isPersona => layout == LayoutKind.sonar;
  bool get isGlass => material == MaterialStyle.glass;

  Skin asSkin(Skin base) {
    if (isPersona) return base;
    return Skin(
      id: base.id,
      displayName: base.displayName,
      background: palette.background,
      accent: base.accentPinned ? base.accent : palette.accent,
      accentDeep: base.accentPinned ? base.accentDeep : palette.accentDeep,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      panel: palette.surface,
      onAccent: base.accentPinned ? base.onAccent : palette.onAccent,
      accentPinned: base.accentPinned,
      skewDegrees: skewDegrees,
      contextLabel: base.contextLabel,
      nowPlayingWordmark: base.nowPlayingWordmark,
      names: base.names,
    );
  }
}

class PresentationScope extends InheritedWidget {
  const PresentationScope({
    super.key,
    required this.presentation,
    required super.child,
  });

  final Presentation presentation;

  static Presentation of(BuildContext context, {required Skin fallback}) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PresentationScope>();
    return scope?.presentation ?? Presentation.forSkin(fallback);
  }

  static Skin uiSkin(BuildContext context, Skin chosen) =>
      of(context, fallback: chosen).asSkin(chosen);

  @override
  bool updateShouldNotify(PresentationScope oldWidget) =>
      oldWidget.presentation != presentation;
}

Presentation presentationFor(LayoutKind layout, Skin skin,
    {int paletteIndex = 0}) {
  final kit = layout.kit;
  if (layout == LayoutKind.sonar) {
    return Presentation(
      layout: layout,
      palette: LayoutPalette.fromSkin(skin),
      material: MaterialStyle.flat,
      motion: MotionSpec.persona,
      arrangement: ScreenLayout.persona,
      kit: kit,
      skewDegrees: skin.skewDegrees,
    );
  }

  final palettes = kit.palettes;
  return Presentation(
    layout: layout,
    palette: palettes[paletteIndex % palettes.length].palette,
    material: layout == LayoutKind.glass ? MaterialStyle.glass : MaterialStyle.flat,
    motion: MotionSpec.restrained,
    arrangement: ScreenLayout.plain,
    kit: kit.withPalette(palettes[paletteIndex % palettes.length].palette),
  );
}

@immutable
class NamedPalette {
  const NamedPalette(this.name, this.palette);
  final String name;
  final LayoutPalette palette;
}

const List<NamedPalette> kSolidPalettes = [
  NamedPalette('Forest', LayoutPalette(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFFFFFFF),

    textSecondary: Color(0xFFA7A7A7),
    accent: Color(0xFF1DB954),
    accentDeep: Color(0xFF14833B),
    onAccent: Color(0xFF0B0B0B),
    border: Color(0xFF2A2A2A),
    shadow: Color(0x00000000),
    ambient: [Color(0x5C1DB954), Color(0x463B7DD8), Color(0x381E8E4E), Color(0x2848B0A0)],
    pageFill: Color(0xB3121212),
  )),
  NamedPalette('Midnight', LayoutPalette(

    background: Color(0xFF0B1020),
    surface: Color(0xFF161E31),
    textPrimary: Color(0xFFF2F6FF),

    textSecondary: Color(0xFFA9B6D0),
    accent: Color(0xFF4C8DFF),
    accentDeep: Color(0xFF2F6BD6),
    onAccent: Color(0xFF061024),
    border: Color(0xFF263352),
    shadow: Color(0x00000000),

    ambient: [Color(0x5C4C8DFF), Color(0x467FD1FF), Color(0x382F6BD6), Color(0x2A22466B)],
    pageFill: Color(0xB30B1020),
  )),
  NamedPalette('Ember', LayoutPalette(

    background: Color(0xFF14100E),
    surface: Color(0xFF241C17),
    textPrimary: Color(0xFFFFF6F0),

    textSecondary: Color(0xFFC3AAA0),
    accent: Color(0xFFFF7A45),
    accentDeep: Color(0xFFC9531F),
    onAccent: Color(0xFF1A0B04),
    border: Color(0xFF3A2C24),
    shadow: Color(0x00000000),
    ambient: [Color(0x2AFF7A45), Color(0x1EE8B45C), Color(0x16C9531F), Color(0x122B1A12)],
    pageFill: Color(0xB314100E),
  )),
];

const List<NamedPalette> kGlassPalettes = [
  NamedPalette('Aurora', LayoutPalette(
    background: Color(0xFF0E1116),
    surface: Color(0x33FFFFFF),
    textPrimary: Color(0xFFF7F9FC),

    textSecondary: Color(0xFFB4BEC9),
    accent: Color(0xFF7FD1FF),
    accentDeep: Color(0xFF4FA8D8),
    onAccent: Color(0xFF06121C),
    border: Color(0x59FFFFFF),
    shadow: Color(0x00000000),
    pageFill: Color(0x5E0E1116),

    ambient: [Color(0x337EE0C3), Color(0x2B80B5EA), Color(0x24E68B9B), Color(0x21E8B45C)],
  )),
  NamedPalette('Jade', LayoutPalette(

    background: Color(0xFF0C1411),
    surface: Color(0x30FFFFFF),
    textPrimary: Color(0xFFF4FBF7),

    textSecondary: Color(0xFFAEC4B9),
    accent: Color(0xFF7FE0B0),
    accentDeep: Color(0xFF46A87D),
    onAccent: Color(0xFF04140D),
    border: Color(0x55FFFFFF),

    shadow: Color(0x00000000),
    pageFill: Color(0x5E0C1411),
    ambient: [Color(0x337FE0B0), Color(0x2B4FA8D8), Color(0x1E6FC8A0), Color(0x1A9FD8C4)],
  )),
  NamedPalette('Sunset', LayoutPalette(

    background: Color(0xFF150F14),
    surface: Color(0x33FFFFFF),
    textPrimary: Color(0xFFFDF7F4),

    textSecondary: Color(0xFFC8B4BA),
    accent: Color(0xFFFFA67F),
    accentDeep: Color(0xFFD06F45),
    onAccent: Color(0xFF1C0A04),
    border: Color(0x5EFFFFFF),

    shadow: Color(0x00000000),
    pageFill: Color(0x8C150F14),
    ambient: [Color(0x33E68B9B), Color(0x2BE8B45C), Color(0x24FFA67F), Color(0x1E9B6BC8)],
  )),
];
