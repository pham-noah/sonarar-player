library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

/// Everything the PERSONALIZE screen owns, in one record.
///
/// The skin still decides the room — background, panel, text, skew, wordmark.
/// This decides only three things: what is painted behind the room, where the
/// accent comes from, and which Home sections show in which order. Keeping it
/// one document is what stops a fourth pref key being invented per widget.
/// The app has four places you look at. Each may hang its own picture; the
/// accent does not travel with them, because four accents is an app arguing
/// with itself.
enum SurfaceId { home, library, search, player }

/// What one surface shows behind and around it. Null means "whatever the
/// default is", which is why a fresh install needs no entries here at all.
class SurfaceLook {
  const SurfaceLook({this.room, this.art});

  /// Photo file name inside `<library>/backgrounds/`.
  final String? room;

  /// Art picture: `bundle/frame.png`, relative to `<library>/art/`.
  final String? art;

  bool get isSet => room != null || art != null;

  SurfaceLook copyWith({String? room, String? art, bool clearRoom = false, bool clearArt = false}) =>
      SurfaceLook(
        room: clearRoom ? null : (room ?? this.room),
        art: clearArt ? null : (art ?? this.art),
      );

  Map<String, Object?> toJson() => {
        if (room != null) 'room': room,
        if (art != null) 'art': art,
      };

  static SurfaceLook fromJson(Object? raw) {
    if (raw is! Map) return const SurfaceLook();
    String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
    return SurfaceLook(room: str(raw['room']), art: str(raw['art']));
  }
}

class Personalization {
  const Personalization({
    this.backdrop = BackdropSpec.none,
    this.accent = const AccentSpec(),
    this.home = HomeLayout.defaults,
    this.surfaces = const {},
    this.bundle,
  });

  final BackdropSpec backdrop;
  final AccentSpec accent;
  final HomeLayout home;

  /// Per-place pictures. Empty is the normal state: one picture everywhere.
  final Map<SurfaceId, SurfaceLook> surfaces;

  /// The art bundle the app wears, by folder name. Null is the built-in art.
  final String? bundle;

  /// The photo this place wears: its own, or the default one.
  ///
  /// A per-surface picture carries its own framing with it, so a photo that
  /// was cropped for the player is not re-cropped for Library.
  BackdropSpec backdropFor(SurfaceId surface) {
    final room = surfaces[surface]?.room;
    if (room == null) return backdrop;
    // The per-place photo keeps the default's framing: one picture, one set of
    // sliders. Framing belongs to the picture, and only the picture changed.
    return backdrop.copyWith(file: room);
  }

  static const Personalization defaults = Personalization();

  bool get isDefault =>
      !backdrop.isSet &&
      accent.source == AccentSource.skin &&
      home.order == HomeLayout.defaults.order &&
      home.hidden.isEmpty &&
      surfaces.isEmpty &&
      bundle == null;

  Personalization copyWith({
    BackdropSpec? backdrop,
    AccentSpec? accent,
    HomeLayout? home,
    Map<SurfaceId, SurfaceLook>? surfaces,
    String? bundle,
    bool clearBundle = false,
  }) =>
      Personalization(
        backdrop: backdrop ?? this.backdrop,
        accent: accent ?? this.accent,
        home: home ?? this.home,
        surfaces: surfaces ?? this.surfaces,
        bundle: clearBundle ? null : (bundle ?? this.bundle),
      );

  /// Writes one place's look, dropping the entry when it says nothing.
  Personalization withSurface(SurfaceId surface, SurfaceLook look) {
    final next = Map<SurfaceId, SurfaceLook>.from(surfaces);
    if (look.isSet) {
      next[surface] = look;
    } else {
      next.remove(surface);
    }
    return copyWith(surfaces: next);
  }

  Map<String, Object?> toJson() => {
        'v': 1,
        'backdrop': backdrop.toJson(),
        'accent': accent.toJson(),
        'home': home.toJson(),
        if (bundle != null) 'bundle': bundle,
        if (surfaces.isNotEmpty)
          'surfaces': {
            for (final e in surfaces.entries) e.key.name: e.value.toJson(),
          },
      };

  String encode() => jsonEncode(toJson());

  /// Never throws. A theme file that cannot be read is the same as no theme,
  /// because a music player that refuses to open is worse than one that looks
  /// like it did yesterday.
  static Personalization decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return defaults;
      return Personalization(
        backdrop: BackdropSpec.fromJson(decoded['backdrop']),
        accent: AccentSpec.fromJson(decoded['accent']),
        home: HomeLayout.fromJson(decoded['home']),
        surfaces: _surfacesFrom(decoded['surfaces']),
        bundle: decoded['bundle'] is String && (decoded['bundle'] as String).isNotEmpty
            ? decoded['bundle'] as String
            : null,
      );
    } catch (_) {
      return defaults;
    }
  }
}

Map<SurfaceId, SurfaceLook> _surfacesFrom(Object? raw) {
  if (raw is! Map) return const {};
  final out = <SurfaceId, SurfaceLook>{};
  for (final entry in raw.entries) {
    final surface = SurfaceId.values
        .where((s) => s.name == entry.key)
        .cast<SurfaceId?>()
        .firstWhere((s) => s != null, orElse: () => null);
    if (surface == null) continue;
    final look = SurfaceLook.fromJson(entry.value);
    if (look.isSet) out[surface] = look;
  }
  return out;
}

/// A photo behind the app.
///
/// `focusX` / `focusY` are the point of the image the user wants kept visible,
/// in 0..1 of the image. Offsets are derived from that at paint time so the
/// same photo survives a different viewport shape; storing raw pixel offsets
/// instead would drift the moment the phone rotates.
class BackdropSpec {
  const BackdropSpec({
    this.file,
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.scale = 1,
    this.rotationDeg = 0,
    this.blur = 0,
    this.dim = 0.35,
    this.tint = true,
    this.coverOnPlayer = false,
  });

  static const BackdropSpec none = BackdropSpec();

  /// File name inside `<library>/backgrounds/`. Relative so moving the library
  /// folder does not break the theme.
  final String? file;

  final double focusX;
  final double focusY;
  final double scale;
  final double rotationDeg;

  /// Logical pixels of blur, baked into the cached copy rather than applied per
  /// frame — a BackdropFilter here would re-blur on every scroll tick.
  final double blur;

  /// Black scrim under the text, 0..1.
  final double dim;

  /// Blend the skin's accent over the photo so the image belongs to the skin
  /// instead of fighting it.
  final bool tint;

  /// On the player, use the current track's cover instead of the photo.
  final bool coverOnPlayer;

  bool get isSet => file != null && file!.isNotEmpty;

  BackdropSpec copyWith({
    String? file,
    bool clearFile = false,
    double? focusX,
    double? focusY,
    double? scale,
    double? rotationDeg,
    double? blur,
    double? dim,
    bool? tint,
    bool? coverOnPlayer,
  }) =>
      BackdropSpec(
        file: clearFile ? null : (file ?? this.file),
        focusX: _clamp01(focusX ?? this.focusX),
        focusY: _clamp01(focusY ?? this.focusY),
        scale: (scale ?? this.scale).clamp(1.0, 4.0),
        rotationDeg: (rotationDeg ?? this.rotationDeg).clamp(-180.0, 180.0),
        blur: (blur ?? this.blur).clamp(0.0, 24.0),
        dim: _clamp01(dim ?? this.dim),
        tint: tint ?? this.tint,
        coverOnPlayer: coverOnPlayer ?? this.coverOnPlayer,
      );

  Map<String, Object?> toJson() => {
        'file': file,
        'fx': focusX,
        'fy': focusY,
        'scale': scale,
        'rot': rotationDeg,
        'blur': blur,
        'dim': dim,
        'tint': tint,
        'cover': coverOnPlayer,
      };

  factory BackdropSpec.fromJson(Object? raw) {
    if (raw is! Map) return none;
    final f = raw['file'];
    return BackdropSpec(
      file: f is String && f.isNotEmpty ? f : null,
      focusX: _clamp01(_num(raw['fx'], 0.5)),
      focusY: _clamp01(_num(raw['fy'], 0.5)),
      scale: _num(raw['scale'], 1).clamp(1.0, 4.0),
      rotationDeg: _num(raw['rot'], 0).clamp(-180.0, 180.0),
      blur: _num(raw['blur'], 0).clamp(0.0, 24.0),
      dim: _clamp01(_num(raw['dim'], 0.35)),
      tint: raw['tint'] is bool ? raw['tint'] as bool : true,
      coverOnPlayer: raw['cover'] is bool ? raw['cover'] as bool : false,
    );
  }
}

enum AccentSource { skin, image, manual }

/// Where the accent comes from. Exactly one source, declared — an accent that
/// is "the skin, unless a photo overrode it, unless the user picked one" is
/// three authorities over one colour and every screen disagrees eventually.
class AccentSpec {
  const AccentSpec({this.source = AccentSource.skin, this.value});

  final AccentSource source;

  /// ARGB, only meaningful for [AccentSource.image] and [AccentSource.manual].
  final int? value;

  bool get hasColour => value != null;

  AccentSpec copyWith({AccentSource? source, int? value, bool clearValue = false}) => AccentSpec(
        source: source ?? this.source,
        value: clearValue ? null : (value ?? this.value),
      );

  Map<String, Object?> toJson() => {'source': source.name, 'value': value};

  factory AccentSpec.fromJson(Object? raw) {
    if (raw is! Map) return const AccentSpec();
    final name = raw['source'];
    final source = AccentSource.values.firstWhere(
      (s) => s.name == name,
      orElse: () => AccentSource.skin,
    );
    final v = raw['value'];
    return AccentSpec(source: source, value: v is int ? v : null);
  }
}

/// Home's sections, in the order the app declares them.
enum HomeSection { now, continueListening, rediscover, jumpBackIn, quickPick, fromLibrary, recap }

class HomeLayout {
  const HomeLayout({required this.order, this.hidden = const {}});

  static const List<HomeSection> defaultOrder = [
    HomeSection.now,
    HomeSection.continueListening,
    HomeSection.rediscover,
    HomeSection.jumpBackIn,
    HomeSection.quickPick,
    HomeSection.fromLibrary,
    HomeSection.recap,
  ];

  static const HomeLayout defaults = HomeLayout(order: defaultOrder);

  final List<HomeSection> order;
  final Set<HomeSection> hidden;

  /// Every section in the saved order, hidden ones included — what the reorder
  /// list draws, so a hidden section can be turned back on.
  List<HomeSection> get all {
    final seen = <HomeSection>{};
    return [
      for (final s in [...order, ...defaultOrder])
        if (seen.add(s)) s,
    ];
  }

  /// What the screen should draw: the saved order, with anything the app has
  /// learned since appended rather than silently dropped, minus what is hidden.
  List<HomeSection> get visible {
    final seen = <HomeSection>{};
    final out = <HomeSection>[];
    for (final s in [...order, ...defaultOrder]) {
      if (!seen.add(s)) continue;
      if (hidden.contains(s)) continue;
      out.add(s);
    }
    return out;
  }

  HomeLayout copyWith({List<HomeSection>? order, Set<HomeSection>? hidden}) =>
      HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);

  HomeLayout move(HomeSection section, int to) {
    final list = [...all];
    final from = list.indexOf(section);
    if (from < 0) return this;
    final target = to.clamp(0, list.length - 1);
    list.removeAt(from);
    list.insert(target, section);
    return copyWith(order: list);
  }

  HomeLayout toggle(HomeSection section) {
    final next = {...hidden};
    if (!next.remove(section)) next.add(section);
    return copyWith(hidden: next);
  }

  Map<String, Object?> toJson() => {
        'order': [for (final s in order) s.name],
        'hidden': [for (final s in hidden) s.name],
      };

  factory HomeLayout.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final order = <HomeSection>[];
    final rawOrder = raw['order'];
    if (rawOrder is List) {
      for (final name in rawOrder) {
        for (final s in HomeSection.values) {
          if (s.name == name && !order.contains(s)) order.add(s);
        }
      }
    }
    final hidden = <HomeSection>{};
    final rawHidden = raw['hidden'];
    if (rawHidden is List) {
      for (final name in rawHidden) {
        for (final s in HomeSection.values) {
          if (s.name == name) hidden.add(s);
        }
      }
    }
    if (order.isEmpty) return HomeLayout(order: defaultOrder, hidden: hidden);
    return HomeLayout(order: order, hidden: hidden);
  }
}

// ---- accent maths ---------------------------------------------------------

/// The accent the app should actually use, given the skin's own and the spec.
Color accentFor(Color skinAccent, AccentSpec spec) {
  if (spec.source == AccentSource.skin) return skinAccent;
  final v = spec.value;
  if (v == null) return skinAccent;
  return Color(v);
}

/// Text placed ON the accent. Recomputed rather than copied from the skin,
/// which is what breaks when a light accent meets white glyphs.
Color onAccentFor(Color accent) =>
    accent.computeLuminance() > 0.45 ? const Color(0xFF101014) : const Color(0xFFF7F5F2);

/// The deeper shade used for shadows and pressed states.
Color accentDeepFor(Color accent) {
  final hsl = _toHsl(accent);
  return _fromHsl(hsl.h, hsl.s, (hsl.l - 0.18).clamp(0.05, 0.95));
}

/// WCAG contrast, 1..21. Used to warn rather than to refuse: the user may want
/// a low-contrast accent, but they should not get one by accident.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pick an accent out of a photo: the most saturated colour that is neither
/// almost black nor almost white, chosen by hue bucket so one bright object
/// does not win, and averaged inside its bucket so the result is a colour
/// rather than a stray pixel.
Color? pickAccentFromPixels(Uint8List rgba, {int stride = 4}) {
  if (rgba.length < 4) return null;
  final weight = List<double>.filled(12, 0);
  final sumR = List<double>.filled(12, 0);
  final sumG = List<double>.filled(12, 0);
  final sumB = List<double>.filled(12, 0);

  for (var i = 0; i + 3 < rgba.length; i += stride) {
    final r = rgba[i] / 255.0;
    final g = rgba[i + 1] / 255.0;
    final b = rgba[i + 2] / 255.0;
    final hi = math.max(r, math.max(g, b));
    final lo = math.min(r, math.min(g, b));
    if (hi < 0.12 || lo > 0.93) continue;
    final sat = hi <= 0 ? 0.0 : (hi - lo) / hi;
    if (sat < 0.18) continue;
    final hue = _hue(r, g, b, hi, lo);
    final bucket = (hue / 30).floor().clamp(0, 11);
    final w = sat * hi;
    weight[bucket] += w;
    sumR[bucket] += r * w;
    sumG[bucket] += g * w;
    sumB[bucket] += b * w;
  }

  var best = -1;
  var bestWeight = 0.0;
  for (var i = 0; i < weight.length; i++) {
    if (weight[i] > bestWeight) {
      bestWeight = weight[i];
      best = i;
    }
  }
  if (best < 0 || bestWeight <= 0) return null;

  final r = sumR[best] / bestWeight;
  final g = sumG[best] / bestWeight;
  final b = sumB[best] / bestWeight;
  final colour = Color.from(alpha: 1, red: r, green: g, blue: b);
  // Lift a dark pick enough to be usable as an accent on a dark panel.
  final hsl = _toHsl(colour);
  if (hsl.l < 0.42) {
    return _fromHsl(hsl.h, math.min(1.0, hsl.s * 1.15), 0.55);
  }
  return colour;
}

class _Hsl {
  const _Hsl(this.h, this.s, this.l);
  final double h;
  final double s;
  final double l;
}

_Hsl _toHsl(Color c) {
  final r = c.r;
  final g = c.g;
  final b = c.b;
  final hi = math.max(r, math.max(g, b));
  final lo = math.min(r, math.min(g, b));
  final l = (hi + lo) / 2;
  if (hi == lo) return _Hsl(0, 0, l);
  final d = hi - lo;
  final s = l > 0.5 ? d / (2 - hi - lo) : d / (hi + lo);
  return _Hsl(_hue(r, g, b, hi, lo), s, l);
}

double _hue(double r, double g, double b, double hi, double lo) {
  final d = hi - lo;
  if (d == 0) return 0;
  double h;
  if (hi == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (hi == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return h * 60;
}

Color _fromHsl(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  double r = 0, g = 0, b = 0;
  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  return Color.from(alpha: 1, red: r + m, green: g + m, blue: b + m);
}

double _clamp01(double v) => v.isNaN ? 0.5 : v.clamp(0.0, 1.0);

double _num(Object? v, double fallback) => v is num && v.isFinite ? v.toDouble() : fallback;
