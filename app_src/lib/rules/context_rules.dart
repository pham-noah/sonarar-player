library;

import 'dart:convert';

import '../theme/skin.dart' show SkinId;
import '../theme/skin_policy.dart' show ContextBand, ManualMode;
import 'rules_engine.dart' show PlaylistContext;

enum WeatherWant {
  any,

  rain,

  snow,
}

enum PlaceWant {
  any,

  atPlace,

  anywhere,
}

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  String fold(String s) => s.replaceAll('_', '').toLowerCase();
  final want = fold(raw);
  for (final v in values) {
    if (fold(v.name) == want) return v;
  }
  return null;
}

String bandLabel(ContextBand band) => switch (band) {
      ContextBand.darkHour => 'dark hour',
      ContextBand.morning => 'morning',
      ContextBand.afternoon => 'afternoon',
      ContextBand.evening => 'evening',
      ContextBand.night => 'night',
    };

class ContextRule {
  const ContextRule({
    required this.id,
    required this.priority,
    this.band,
    this.weather = WeatherWant.any,
    this.mode,
    this.placeId,
    this.place = PlaceWant.any,
    this.playlist,
    this.theme,
  });

  final String id;

  final int priority;

  final ContextBand? band;
  final WeatherWant weather;
  final ManualMode? mode;

  final String? placeId;

  final PlaceWant place;

  final String? playlist;

  final SkinId? theme;

  bool matches(PlaylistContext ctx) {
    if (band != null && ctx.band != band) return false;
    if (mode != null && ctx.mode != mode) return false;
    if (weather == WeatherWant.rain && !ctx.raining) return false;

    if (weather == WeatherWant.snow && !ctx.snowing) return false;
    if (placeId != null && ctx.placeId != placeId) return false;

    if (place == PlaceWant.anywhere) {
      if (!ctx.hasPlaceReading) return false;
      if (ctx.placeId != null) return false;
    }
    return true;
  }

  String describe() {
    final parts = <String>[];
    if (band != null) parts.add('time is ${bandLabel(band!)}');
    if (mode != null) parts.add('mode is ${mode!.label}');
    if (weather == WeatherWant.rain) parts.add('it is raining');
    if (weather == WeatherWant.snow) parts.add('it is snowing');
    if (placeId != null) parts.add('you are at $placeId');
    if (place == PlaceWant.anywhere) parts.add('you are in none of your places');
    final when = parts.isEmpty ? 'always' : parts.join(' and ');
    final what = playlist == null ? 'a theme change' : 'the "$playlist" playlist';
    return '$when → $what';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'priority': priority,
        'when': {
          if (band != null) 'time_band': band!.name,
          if (mode != null) 'mode': mode!.name,
          if (weather == WeatherWant.rain) 'weather': 'rain',
          if (weather == WeatherWant.snow) 'weather': 'snow',
          if (placeId != null) 'place': placeId,

          if (place == PlaceWant.anywhere) 'place': 'anywhere',
        },
        if (playlist != null) 'playlist': playlist,
        if (theme != null) 'theme': theme!.name,
      };
}

class ContextRules {
  ContextRules(List<ContextRule> raw)

      : rules = List<ContextRule>.from(raw)
          ..sort((a, b) => b.priority.compareTo(a.priority));

  static final ContextRules empty = ContextRules(const []);

  final List<ContextRule> rules;

  bool get isEmpty => rules.isEmpty;
  int get length => rules.length;

  ContextRule? firstMatch(PlaylistContext ctx) {
    for (final r in rules) {
      if (r.matches(ctx)) return r;
    }
    return null;
  }

  String encode() =>
      const JsonEncoder.withIndent('  ').convert({'rules': [
        for (final r in rules) r.toJson(),
      ]});

  static ContextRules decode(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is! Map) return ContextRules.empty;
      final list = raw['rules'];
      if (list is! List) return ContextRules.empty;
      final out = <ContextRule>[];
      for (final item in list) {
        if (item is! Map) continue;
        final rule = _ruleFromJson(item.cast<String, Object?>());
        if (rule != null) out.add(rule);
      }
      return ContextRules(out);
    } on FormatException {
      return ContextRules.empty;
    }
  }

  static ContextRule? _ruleFromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) return null;

    final when = json['when'];
    final w = when is Map ? when.cast<String, Object?>() : const <String, Object?>{};

    final bandName = w['time_band'];
    final band = bandName == null
        ? null
        : _enumByName(ContextBand.values, bandName);

    if (bandName != null && band == null) return null;

    final modeName = w['mode'];
    final mode =
        modeName == null ? null : _enumByName(ManualMode.values, modeName);
    if (modeName != null && mode == null) return null;

    final weather = switch (w['weather']) {
      null => WeatherWant.any,
      'rain' => WeatherWant.rain,
      'snow' => WeatherWant.snow,
      'any' => WeatherWant.any,
      _ => null,
    };
    if (weather == null) return null;

    final placeRaw = w['place'];
    final placeStr = placeRaw is String && placeRaw.trim().isNotEmpty
        ? placeRaw.trim()
        : null;
    final isAnywhere = placeStr != null && placeStr.toLowerCase() == 'anywhere';
    final place = isAnywhere ? null : placeStr;

    final themeName = json['theme'];
    final theme =
        themeName == null ? null : _enumByName(SkinId.values, themeName);
    if (themeName != null && theme == null) return null;

    final playlist = json['playlist'];

    return ContextRule(
      id: id.trim(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      band: band,
      weather: weather,
      mode: mode,
      placeId: place,
      place: isAnywhere ? PlaceWant.anywhere : PlaceWant.any,
      playlist: playlist is String && playlist.trim().isNotEmpty
          ? playlist.trim()
          : null,
      theme: theme,
    );
  }
}
