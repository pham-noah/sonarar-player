library;

import 'dart:convert';
import 'dart:io';

import '../theme/personalization.dart';
import '../theme/skin.dart';

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.skinId,
    this.artSkinId,
    this.languageSkinId,
    this.layoutId,
    this.personalization,
    this.builtIn = false,
  });

  final String id;
  final String name;

  final String? layoutId;

  /// The theme's personalization: backdrop, accent source, Home order. Null on
  /// presets written before 0.2.0, which simply means "whatever the app has".
  final Personalization? personalization;

  final SkinId skinId;

  final SkinId? artSkinId;

  final SkinId? languageSkinId;

  SkinId get effectiveLanguageSkin => languageSkinId ?? skinId;

  final bool builtIn;

  SkinId get effectiveArtSkin => artSkinId ?? skinId;

  ThemePreset copyWith({
    String? id,
    String? name,
    SkinId? skinId,
    SkinId? artSkinId,
    SkinId? languageSkinId,
    String? layoutId,
    Personalization? personalization,
    bool clearArt = false,
    bool clearLanguage = false,
  }) =>
      ThemePreset(
        id: id ?? this.id,
        name: name ?? this.name,
        skinId: skinId ?? this.skinId,

        artSkinId: clearArt ? null : (artSkinId ?? this.artSkinId),
        languageSkinId:
            clearLanguage ? null : (languageSkinId ?? this.languageSkinId),
        layoutId: layoutId ?? this.layoutId,
        personalization: personalization ?? this.personalization,
        builtIn: false,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'skin': skinId.name,
        if (artSkinId != null) 'art': artSkinId!.name,
        if (languageSkinId != null) 'language': languageSkinId!.name,

        if (layoutId != null) 'layout': layoutId,
        if (personalization != null) 'personalize': personalization!.toJson(),
      };

  static ThemePreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;

    final skin = _byName(raw['skin']);
    if (skin == null) return null;

    return ThemePreset(
      id: id.trim(),
      name: name.trim(),
      skinId: skin,

      artSkinId: _byName(raw['art']),
      languageSkinId: _byName(raw['language']),

      layoutId: (raw['layout'] is String &&
              (raw['layout'] as String).trim().isNotEmpty)
          ? (raw['layout'] as String).trim()
          : null,
      personalization: raw['personalize'] is Map
          ? Personalization.decode(jsonEncode(raw['personalize']))
          : null,
    );
  }

  static SkinId? _byName(Object? raw) {
    if (raw is! String) return null;
    final name = raw.toLowerCase();

    const legacy = {'p3r': 'abyss', 'p4r': 'amber', 'p5r': 'crimson'};
    final wanted = legacy[name] ?? name;
    for (final candidate in SkinId.values) {
      if (candidate.name == wanted) return candidate;
    }
    return null;
  }
}

final List<ThemePreset> kBuiltInPresets = [
  for (final s in kAllSkins)
    ThemePreset(
      id: 'builtin_${s.id.name}',
      name: s.displayName,
      skinId: s.id,
      layoutId: 'sonar',
      // A theme has to be able to say what every part of the look is, or
      // switching to it leaves the previous theme's pictures and accent behind.
      personalization: Personalization.defaults,
      builtIn: true,
    ),
];

String freshPresetId([Set<String> existing = const {}]) {
  final base = 'tp_${DateTime.now().microsecondsSinceEpoch}';
  if (!existing.contains(base)) return base;
  var n = 2;
  while (existing.contains('${base}_$n')) {
    n++;
  }
  return '${base}_$n';
}

class ThemePresetStore {
  ThemePresetStore(this.file);

  final File file;

  static List<ThemePreset> decode(String source) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      return const [];
    }
    if (raw is! Map) return const [];
    final list = raw['presets'];
    if (list is! List) return const [];
    final out = <ThemePreset>[];
    final seen = <String>{};
    for (final item in list) {
      final p = ThemePreset.fromJson(item);

      if (p != null && seen.add(p.id)) out.add(p);
    }
    return out;
  }

  Future<List<ThemePreset>> load() async {
    if (!file.existsSync()) return const [];
    try {
      return decode(await file.readAsString());
    } on FormatException {
      return const [];
    } on FileSystemException {
      return const [];
    }
  }

  Future<void> save(List<ThemePreset> presets) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      'presets': [for (final p in presets) p.toJson()],
    }));
  }
}
