library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'personalization.dart';

enum SkinId {
  abyss,
  amber,
  crimson,

  minimal,

  mono,
  bloom,
}

@immutable
class Skin {
  const Skin({
    required this.id,
    required this.displayName,
    required this.background,
    required this.accent,
    required this.accentDeep,
    required this.textPrimary,
    required this.textSecondary,
    required this.panel,
    required this.onAccent,
    required this.skewDegrees,
    required this.contextLabel,
    required this.nowPlayingWordmark,
    this.names = const {},
    this.accentPinned = false,
  });

  /// True when the accent was chosen by the user rather than inherited.
  ///
  /// A presentation (Glass, Solid) recolours the accent from its own palette.
  /// That is right for a palette's look and wrong for a choice someone made, so
  /// a pinned accent survives that resolution instead of being replaced by it.

  final SkinId id;

  final String displayName;

  final Color background;

  final Color accent;
  final Color accentDeep;

  final Color textPrimary;
  final Color textSecondary;

  final Color panel;

  final Color onAccent;

  bool get isLight => background.computeLuminance() > 0.5;

  Color get slabShadow => isLight
      ? textPrimary.withValues(alpha: 0.10)
      : const Color(0x8C000000);

  final double skewDegrees;

  final String contextLabel;

  final String nowPlayingWordmark;

  final Map<String, String> names;

  final bool accentPinned;

  String word(String key, String fallback) => names[key] ?? fallback;

  /// The same skin wearing a different accent.
  ///
  /// A skin's accent is not one colour: `accentDeep` and `onAccent` are derived
  /// from it, and copying them across would put white glyphs on a pale accent.
  /// Only the three accent slots move — background, panel, text, skew and the
  /// wordmark stay the skin's, which is what keeps it recognisable.
  Skin withAccent(Color accent) => Skin(
        id: id,
        displayName: displayName,
        background: background,
        accent: accent,
        accentDeep: accentDeepFor(accent),
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        panel: panel,
        onAccent: onAccentFor(accent),
        accentPinned: true,
        skewDegrees: skewDegrees,
        contextLabel: contextLabel,
        nowPlayingWordmark: nowPlayingWordmark,
        names: names,
      );
}

abstract final class WordKey {
  static const String libraryRoom = 'room.library';

  static const String affinityRoom = 'room.affinity';

  static const String modeBattle = 'mode.battle';

  static const String modeDeepNight = 'mode.deepNight';

  static const String bandDeepNight = 'band.deepNight';

  static const String catalogue = 'room.catalogue';

  static const String merge = 'room.merge';

  static const String tools = 'room.tools';
}

const Skin kSkinAbyss = Skin(
  id: SkinId.abyss,
  displayName: 'Abyss',
  background: Color(0xFF04080F),
  accent: Color(0xFF3CE0D0),
  accentDeep: Color(0xFF2F6FD0),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFE2EEFA),
  panel: Color(0x2616EBFF),
  onAccent: Color(0xFF03121E),
  skewDegrees: 15.0,
  contextLabel: 'DEEP NIGHT',
  nowPlayingWordmark: 'THE DEEP',
  names: {
    WordKey.libraryRoom: 'THE ARCHIVE',
    WordKey.catalogue: 'CATALOGUE',
    WordKey.merge: 'MERGE',
    WordKey.tools: 'TOOLS',
    WordKey.affinityRoom: 'AFFINITY',
    WordKey.modeBattle: 'NIGHTFALL',
    WordKey.modeDeepNight: 'DEEP NIGHT',
    WordKey.bandDeepNight: 'DEEP NIGHT',
  },
);

const Skin kSkinAmber = Skin(
  id: SkinId.amber,
  displayName: 'Amber',
  background: Color(0xFF000000),
  accent: Color(0xFFF3DF0C),
  accentDeep: Color(0xFFEE8921),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFFDFDFD),
  panel: Color(0x29F3DF0C),
  onAccent: Color(0xFF0A0A0A),
  skewDegrees: 12.0,
  contextLabel: 'LATE AFTERNOON',
  nowPlayingWordmark: 'ON AIR',
  names: {
    WordKey.libraryRoom: 'THE ARCHIVE',
    WordKey.catalogue: 'CATALOGUE',
    WordKey.merge: 'MERGE',
    WordKey.tools: 'TOOLS',
    WordKey.affinityRoom: 'AFFINITY',
    WordKey.modeBattle: 'LATE SHOW',
    WordKey.modeDeepNight: 'STATIC',
    WordKey.bandDeepNight: 'STATIC',
  },
);

const Skin kSkinCrimson = Skin(
  id: SkinId.crimson,
  displayName: 'Crimson',
  background: Color(0xFF0A0A0C),
  accent: Color(0xFFE60012),
  accentDeep: Color(0xFFA3000D),
  textPrimary: Color(0xFFFFFFFF),

  textSecondary: Color(0xFFE8E8EE),
  panel: Color(0xFF1C1C22),
  onAccent: Color(0xFFFFFFFF),
  skewDegrees: 15.0,
  contextLabel: 'SANCTUM',
  nowPlayingWordmark: 'TURN IT UP',
  names: {
    WordKey.libraryRoom: 'THE ARCHIVE',
    WordKey.catalogue: 'CATALOGUE',
    WordKey.merge: 'MERGE',
    WordKey.tools: 'TOOLS',
    WordKey.affinityRoom: 'AFFINITY',
    WordKey.modeBattle: 'SANCTUM',
    WordKey.modeDeepNight: 'BACKSTAGE',
    WordKey.bandDeepNight: 'BACKSTAGE',
  },
);

const Skin kSkinMinimal = Skin(
  id: SkinId.minimal,
  displayName: 'Minimal',

  background: Color(0xFFE9E4DC),
  accent: Color(0xFFE8927C),
  accentDeep: Color(0xFFC96A52),
  textPrimary: Color(0xFF2B2A28),
  textSecondary: Color(0xFF5C5955),
  panel: Color(0xFFFFFFFF),

  onAccent: Color(0xFF2B2A28),
  skewDegrees: 0.0,
  contextLabel: 'AT HOME',
  nowPlayingWordmark: 'NOW',
);

const Skin kSkinMono = Skin(
  id: SkinId.mono,
  displayName: 'Mono',
  background: Color(0xFF121213),
  accent: Color(0xFFD8D8DC),
  accentDeep: Color(0xFF6E6E76),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFF9A9AA2),
  panel: Color(0xFF1E1E20),
  onAccent: Color(0xFF121213),
  skewDegrees: 0.0,
  contextLabel: 'PLAIN',
  nowPlayingWordmark: 'NOW PLAYING',
);

const Skin kSkinBloom = Skin(
  id: SkinId.bloom,
  displayName: 'Bloom',

  background: Color(0xFFF4E4DA),
  accent: Color(0xFFD98BA6),
  accentDeep: Color(0xFFA85F79),
  textPrimary: Color(0xFF33272B),

  textSecondary: Color(0xFF665459),
  panel: Color(0xFFFFF9F6),

  onAccent: Color(0xFF33272B),
  skewDegrees: 8.0,
  contextLabel: 'SOFT HOUR',
  nowPlayingWordmark: 'BLOOM',
);

const List<Skin> kAllSkins = [
  kSkinAbyss,
  kSkinAmber,
  kSkinCrimson,
  kSkinMinimal,
  kSkinBloom,
  kSkinMono,
];

Skin skinFor(SkinId id) => kAllSkins.firstWhere((s) => s.id == id);

abstract final class LayoutSpec {
  static const double fontBase = 22.0;
  static const double fontTitle = 34.0;
  static const double fontSmall = 18.0;

  static const double fontLabel = fontFloor;

  static const double fontFloor = 16.0;

  static const double tapTarget = 56.0;

  static const double gapS = 10.0;

  static const double gapM = 26.0;

  static const double phoneChromeRadius = 30.0;

  static const double tabBarHeight = 70.0;

  static const double miniPlayerClearance = 70.0;

  static const double miniPlayerHeight = 64.0;

  static const double headerArtOverhang = 64.0;

  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(30, 20, 20, 0);

  static const Curve curveOut = Curves.easeOutCubic;

  static const double playButtonWidth = 62.0;
  static const double playButtonHeight = 54.0;

  static const double spectrumHeight = 110.0;
  static const double transportButtonWidth = 42.0;
  static const double transportButtonHeight = 38.0;

  static const double secondaryActionWidth = 42.0;
  static const double secondaryActionHeight = 36.0;
}

  ThemeData themeFor(Skin skin, {Presentation? layout}) {
    final palette = layout?.kit.palette;
    if (palette != null) {
      // The palette owns the room; a pinned accent owns the highlights.
      return _themeFromPalette(palette, accentFrom: skin.accentPinned ? skin : null);
    }
    return _themeFromSkin(skin);
  }

ThemeData _themeFromPalette(LayoutPalette pal, {Skin? accentFrom}) {
  final light = pal.background.computeLuminance() > 0.5;
  final accent = accentFrom?.accent ?? pal.accent;
  final accentDeep = accentFrom?.accentDeep ?? pal.accentDeep;
  final onAccent = accentFrom?.onAccent ?? pal.onAccent;
  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: pal.background,
    colorScheme: light
        ? ColorScheme.light(
            primary: accent,
            secondary: accentDeep,
            surface: pal.background,
            onSurface: pal.textPrimary,
            onPrimary: onAccent,
          )
        : ColorScheme.dark(
            primary: pal.accent,
            secondary: pal.accentDeep,
            surface: pal.background,
            onSurface: pal.textPrimary,
            onPrimary: pal.onAccent,
          ),
  );
}

ThemeData _themeFromSkin(Skin skin) {
  final scheme = skin.isLight
      ? ColorScheme.light(
          primary: skin.accent,
          secondary: skin.accentDeep,
          surface: skin.background,
          onSurface: skin.textPrimary,
          onPrimary: skin.onAccent,
        )
      : ColorScheme.dark(
          primary: skin.accent,
          secondary: skin.accentDeep,
          surface: skin.background,
          onSurface: skin.textPrimary,
          onPrimary: skin.onAccent,
        );
  return ThemeData(
    useMaterial3: true,
    brightness: skin.isLight ? Brightness.light : Brightness.dark,
    scaffoldBackgroundColor: skin.background,
    colorScheme: scheme,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(
        fontSize: LayoutSpec.fontBase,
        height: 1.35,
      ),
      bodyMedium: TextStyle(fontSize: LayoutSpec.fontBase),
      titleLarge: TextStyle(
        fontSize: LayoutSpec.fontTitle,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
      ),
      labelSmall: TextStyle(fontSize: LayoutSpec.fontLabel),
    ).apply(
      bodyColor: skin.textPrimary,
      displayColor: skin.textPrimary,
    ),
  );
}
