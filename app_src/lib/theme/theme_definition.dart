library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'layout_kit.dart';
import 'motion.dart';
import 'surface.dart' show SurfaceRole;
import 'theme_validation.dart';

const int kThemeSchemaVersion = 1;

class ThemeDefinition {
  const ThemeDefinition({
    required this.id,
    required this.displayName,
    required this.palette,
    required this.material,
    required this.motion,
    required this.arrangement,
    required this.chrome,
    this.builtIn = false,
    this.description,
  });

  final String id;

  final String displayName;

  final LayoutPalette palette;
  final MaterialKit material;
  final MotionSpec motion;
  final ScreenLayout arrangement;
  final ChromeKit chrome;

  final bool builtIn;

  final String? description;

  static ThemeDecodeResult decode(Object? json, {String? sourceName}) {
    final src = sourceName ?? 'a theme file';
    if (json is! Map) {
      return ThemeDecodeResult.invalid([
        ThemeIssue('(root)', '$src is not a JSON object')
      ]);
    }
    final map = json.cast<String, Object?>();
    final issues = <ThemeIssue>[];

    final version = map['schema'];
    if (version != null && version != kThemeSchemaVersion) {
      return ThemeDecodeResult.invalid([
        ThemeIssue('schema', '$src declares version $version, and this build reads '
            'v$kThemeSchemaVersion — a newer file may use fields this build does not '
            'know, so it is skipped rather than read with defaults')
      ]);
    }

    final id = _requireString(map, 'id', issues)?.toLowerCase();
    final rawName = _requireString(map, 'displayName', issues);

    final paletteResult = _decodePalette(map['palette']);
    issues.addAll(paletteResult.issues
        .map((i) => ThemeIssue('palette.${i.field}', i.message)));

    issues.addAll(checkPalette(paletteResult.palette)
        .where((i) => i.isError)
        .map((i) => ThemeIssue('palette.${i.field}', i.message)));

    if (id == null || id.isEmpty || issues.isNotEmpty) {
      return ThemeDecodeResult.invalid(issues);
    }

    return ThemeDecodeResult.valid(ThemeDefinition(
      id: id,
      displayName: rawName?.isNotEmpty == true ? rawName! : id,
      description:
          map['description'] is String ? map['description'] as String : null,
      palette: paletteResult.palette,
      material: _decodeMaterial(map['material']),
      motion: _decodeMotion(map['motion']),
      arrangement: _decodeArrangement(map['arrangement']),
      chrome: _decodeChrome(map['chrome']),
      builtIn: map['builtIn'] == true,
    ));
  }

  Map<String, Object?> toJson() => {
        'schema': kThemeSchemaVersion,
        'id': id,
        'displayName': displayName,
        if (description != null) 'description': description,
        'palette': {
          'background': _hex(palette.background),
          'surface': _hex(palette.surface),
          'textPrimary': _hex(palette.textPrimary),
          'textSecondary': _hex(palette.textSecondary),
          'accent': _hex(palette.accent),
          'accentDeep': _hex(palette.accentDeep),
          'onAccent': _hex(palette.onAccent),
          'border': _hex(palette.border),
          'shadow': _hex(palette.shadow),
        },
        'material': {
          'slant': material.slant,
          'edge': material.edge.name,
          'activeFillIsAccent': material.activeFillIsAccent,
          'blur': material.blur,
          'specularEdge': material.specularEdge,
          'castShadow': material.castShadow,
          'transparentInactiveFill': material.transparentInactiveFill,
          'radii': {
            for (final e in material.radii.entries) e.key.name: e.value,
          },
        },
        'motion': {
          'tabTransitionMs': motion.tabTransition.inMilliseconds,

          'arrivalCurve': curveName(motion.arrivalCurve),
          'arrivalAmplitude': motion.arrivalAmplitude,
          'backdropFactor': motion.backdropFactor,
          'enabled': motion.enabled,
        },
        'arrangement': {
          'libraryIsGrid': arrangement.libraryIsGrid,
          'headerScrollsAway': arrangement.headerScrollsAway,
          'contextPlateExists': arrangement.contextPlateExists,
          'tabBarIsFloating': arrangement.tabBarIsFloating,
          'tabBarInsetLeft': arrangement.tabBarInsets.left,
          'tabBarInsetRight': arrangement.tabBarInsets.right,
          'tabBarInsetBottom': arrangement.tabBarInsets.bottom,
          if (arrangement.contentMaxWidth != null)
            'contentMaxWidth': arrangement.contentMaxWidth,
        },
        'chrome': {
          'sectionBand': chrome.sectionBand.name,
          'libraryHeader': chrome.libraryHeader.name,
          'titleForm': chrome.titleForm.name,
          'shellFrame': chrome.shellFrame.name,
          'wordmark': chrome.wordmark,
          'hemisphereScrim': chrome.hemisphereScrim,
          'alfrescoCharacterArt': chrome.alfrescoCharacterArt,
          'artByDefault': chrome.artByDefault,
          'artReachBehindBars': chrome.artReachBehindBars,
          'coverSize': chrome.coverSize,
          'transportTilt': chrome.transportTilt,
          'scrubberBelowTransport': chrome.scrubberBelowTransport,
          'backdropClip': chrome.backdropClip == Clip.none ? 'none' : 'hardEdge',
          'backdropReach': chrome.backdropReach,
          'upNextStrip': chrome.upNextStrip,
          'panelSheetUsesSurface': chrome.panelSheetUsesSurface,
        },
        'builtIn': builtIn,
      };
}

sealed class ThemeDecodeResult {
  const ThemeDecodeResult._();

  const factory ThemeDecodeResult.valid(ThemeDefinition theme) =
      _ThemeDecodeValid;

  const factory ThemeDecodeResult.invalid(List<ThemeIssue> issues) =
      _ThemeDecodeInvalid;

  T when<T>({
    required T Function(ThemeDefinition theme) valid,
    required T Function(List<ThemeIssue> issues) invalid,
  }) {
    final self = this;
    return switch (self) {
      _ThemeDecodeValid() => valid(self.theme),
      _ThemeDecodeInvalid() => invalid(self.issues),
    };
  }
}

final class _ThemeDecodeValid extends ThemeDecodeResult {
  const _ThemeDecodeValid(this.theme) : super._();
  final ThemeDefinition theme;
}

final class _ThemeDecodeInvalid extends ThemeDecodeResult {
  const _ThemeDecodeInvalid(this.issues) : super._();
  final List<ThemeIssue> issues;
}

String? _requireString(
    Map<String, Object?> map, String field, List<ThemeIssue> issues) {
  final v = map[field];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  issues.add(ThemeIssue(field, 'missing, or not a non-empty string'));
  return null;
}

const LayoutPalette _defaultPalette = LayoutPalette(
  background: Color(0xFF000000),
  surface: Color(0xFFFFFFFF),
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFFA0A0A0),
  accent: Color(0xFFFFFFFF),
  accentDeep: Color(0xFF888888),
  onAccent: Color(0xFF000000),
  border: Color(0xFF606060),
  shadow: Color(0x00000000),
);

class _PaletteResult {
  const _PaletteResult(this.palette, this.issues);
  final LayoutPalette palette;
  final List<ThemeIssue> issues;
}

_PaletteResult _decodePalette(Object? raw) {
  if (raw is! Map) return const _PaletteResult(_defaultPalette, []);
  final map = raw.cast<String, Object?>();
  final issues = <ThemeIssue>[];

  Color pick(String field, Color fallback) {
    final v = map[field];
    if (v == null) return fallback;
    final c = _parseColor(v);
    if (c == null) {
      issues.add(ThemeIssue(field, '"$v" is not a #RRGGBB colour'));
      return fallback;
    }
    return c;
  }

  return _PaletteResult(
    LayoutPalette(
      background: pick('background', _defaultPalette.background),
      surface: pick('surface', _defaultPalette.surface),
      textPrimary: pick('textPrimary', _defaultPalette.textPrimary),
      textSecondary: pick('textSecondary', _defaultPalette.textSecondary),
      accent: pick('accent', _defaultPalette.accent),
      accentDeep: pick('accentDeep', _defaultPalette.accentDeep),
      onAccent: pick('onAccent', _defaultPalette.onAccent),
      border: pick('border', _defaultPalette.border),
      shadow: pick('shadow', _defaultPalette.shadow),
    ),
    issues,
  );
}

MaterialKit _decodeMaterial(Object? raw) {
  if (raw is! Map) return MaterialKit.persona;
  final map = raw.cast<String, Object?>();
  final radii = <SurfaceRole, double>{
    for (final role in SurfaceRole.values)
      role: map['radii'] is Map &&
              (map['radii'] as Map)[role.name] is num
          ? ((map['radii'] as Map)[role.name] as num).toDouble()
          : MaterialKit.persona.radii[role]!,
  };
  return MaterialKit(
    radii: radii,
    slant: map['slant'] == true,
    edge: map['edge'] == 'hairline' ? SurfaceEdge.hairline : SurfaceEdge.heavy,
    activeFillIsAccent: map['activeFillIsAccent'] != false,
    blur: (map['blur'] as num?)?.toDouble() ?? 0,
    specularEdge: map['specularEdge'] == true,
    castShadow: map['castShadow'] != false,
    transparentInactiveFill: map['transparentInactiveFill'] != false,
  );
}

MotionSpec _decodeMotion(Object? raw) {
  if (raw is! Map) return MotionSpec.persona;
  final map = raw.cast<String, Object?>();
  return MotionSpec(
    tabTransition: Duration(
      milliseconds: (map['tabTransitionMs'] as num?)?.toInt() ?? 420,
    ),
    arrivalCurve: curveFromName(map['arrivalCurve']),
    arrivalAmplitude: (map['arrivalAmplitude'] as num?)?.toDouble() ?? 1.0,
    backdropFactor: (map['backdropFactor'] as num?)?.toDouble() ?? 1.65,
    enabled: map['enabled'] != false,
  );
}

const Map<String, Curve> _curvesByName = <String, Curve>{
  'overshoot': Curves.easeOutBack,
  'easeOutCubic': Curves.easeOutCubic,
};

String curveName(Curve curve) {
  for (final e in _curvesByName.entries) {
    if (e.value == curve) return e.key;
  }
  throw ArgumentError('no name for curve $curve — add it to _curvesByName');
}

Curve curveFromName(Object? raw) {
  if (raw == null) return MotionCurve.arrival;
  final key = raw.toString();
  final curve = _curvesByName[key];
  if (curve == null) {
    throw ArgumentError('unknown arrival curve "$key" — one of ${_curvesByName.keys.join(', ')}');
  }
  return curve;
}

ScreenLayout _decodeArrangement(Object? raw) {
  if (raw is! Map) return ScreenLayout.persona;
  final map = raw.cast<String, Object?>();
  return ScreenLayout(
    libraryIsGrid: map['libraryIsGrid'] == true,
    headerScrollsAway: map['headerScrollsAway'] == true,
    contextPlateExists: map['contextPlateExists'] == true,
    tabBarIsFloating: map['tabBarIsFloating'] == true,
    tabBarInsets: EdgeInsets.fromLTRB(
      (map['tabBarInsetLeft'] as num?)?.toDouble() ?? 0,
      0,
      (map['tabBarInsetRight'] as num?)?.toDouble() ?? 0,
      (map['tabBarInsetBottom'] as num?)?.toDouble() ?? 0,
    ),
    contentMaxWidth: (map['contentMaxWidth'] as num?)?.toDouble(),
  );
}

ChromeKit _decodeChrome(Object? raw) {
  if (raw is! Map) return ChromeKit.persona;
  final map = raw.cast<String, Object?>();
  return ChromeKit(
    sectionBand: map['sectionBand'] == 'mark'
        ? SectionBandForm.mark
        : SectionBandForm.banner,
    libraryHeader: map['libraryHeader'] == 'appHeader'
        ? HeaderForm.appHeader
        : HeaderForm.sectionBand,
    titleForm:
        map['titleForm'] == 'beside' ? TitleForm.beside : TitleForm.stacked,
    shellFrame: map['shellFrame'] == 'floating'
        ? ShellFrame.floating
        : ShellFrame.docked,
    wordmark: map['wordmark'] == true,
    hemisphereScrim: map['hemisphereScrim'] == true,
    alfrescoCharacterArt: map['alfrescoCharacterArt'] == true,
    artByDefault: map['artByDefault'] == true,
    artReachBehindBars: (map['artReachBehindBars'] as num?)?.toDouble() ?? 0,
    coverSize: (map['coverSize'] as num?)?.toDouble() ?? 156,
    transportTilt: (map['transportTilt'] as num?)?.toDouble() ?? 0,
    scrubberBelowTransport: map['scrubberBelowTransport'] != false,
    backdropClip: map['backdropClip'] == 'none' ? Clip.none : Clip.hardEdge,
    backdropReach: (map['backdropReach'] as num?)?.toDouble() ?? 0,
    upNextStrip: map['upNextStrip'] == true,
    panelSheetUsesSurface: map['panelSheetUsesSurface'] == true,
  );
}

Color? _parseColor(Object? v) {
  if (v is! String) return null;
  var s = v.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return null;
  final n = int.tryParse(s, radix: 16);
  return n == null ? null : Color(n);
}

String _hex(Color c) => '#'
    '${(c.a * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
