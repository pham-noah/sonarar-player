library;

import '../context/weather_codes.dart';
import '../theme/skin.dart';

enum ContextBand { morning, afternoon, evening, night, darkHour }

enum ManualMode {
  battle,

  darkHour;

  String get label => switch (this) {
        ManualMode.battle => 'Energy',
        ManualMode.darkHour => 'Night Hour',
      };

  String get blurb => switch (this) {
        ManualMode.battle =>
          'One tap into the loudest, most driving music here. '
              'Reshuffle reorders the queue from scratch.',
        ManualMode.darkHour =>
          'The small hours, enterable at any time. The jarring short pieces are '
              'allowed in — the hour is meant to feel wrong.',
      };

  ContextBand get band => switch (this) {
        ManualMode.battle => ContextBand.afternoon,
        ManualMode.darkHour => ContextBand.darkHour,
      };
}

enum Sky { unknown, clear, clouds, fog, drizzle, rain, snow, thunder }

Sky skyFrom(WeatherCondition? c) => switch (c) {
      null => Sky.unknown,
      WeatherCondition.unknown => Sky.unknown,
      WeatherCondition.clear => Sky.clear,
      WeatherCondition.clouds => Sky.clouds,
      WeatherCondition.fog => Sky.fog,
      WeatherCondition.drizzle => Sky.drizzle,
      WeatherCondition.rain => Sky.rain,
      WeatherCondition.snow => Sky.snow,
      WeatherCondition.thunder => Sky.thunder,
    };

enum Whereabouts { unknown, home, atPlace, away, commuting }

class PlayContext {
  const PlayContext({
    required this.band,
    required this.localHour,
    this.mode,
    this.placeId,
    this.sky = Sky.unknown,
    this.whereabouts = Whereabouts.unknown,
  });

  final ContextBand band;

  final Sky sky;

  final Whereabouts whereabouts;

  bool get raining => sky == Sky.rain || sky == Sky.drizzle || sky == Sky.thunder;

  bool get snowing => sky == Sky.snow;

  bool get atHome => whereabouts == Whereabouts.home;

  bool get commuting => whereabouts == Whereabouts.commuting;

  bool get hasPlaceReading => whereabouts != Whereabouts.unknown;

  final int localHour;

  final ManualMode? mode;

  final String? placeId;

  bool get isDarkHour => band == ContextBand.darkHour;

  PlayContext copyWith({ManualMode? mode, bool clearMode = false}) => PlayContext(
        band: band,
        sky: sky,
        whereabouts: whereabouts,
        localHour: localHour,
        placeId: placeId,
        mode: clearMode ? null : (mode ?? this.mode),
      );
}

String manualModeName(Skin skin, ManualMode mode) => switch (mode) {
      ManualMode.battle => skin.word(WordKey.modeBattle, mode.label),
      ManualMode.darkHour => skin.word(WordKey.modeDeepNight, mode.label),
    };

String manualModeBlurb(Skin skin, ManualMode mode) {
  return mode.blurb;
}

class SkinPreference {
  const SkinPreference({this.manualSkin, this.setAt});

  final SkinId? manualSkin;

  final DateTime? setAt;

  bool get isManual => manualSkin != null;
}

class SkinPolicy {
  const SkinPolicy();

  ContextBand bandFor(int hour) {
    if (hour == 0) return ContextBand.darkHour;
    if (hour < 6) return ContextBand.night;
    if (hour < 12) return ContextBand.morning;
    if (hour < 17) return ContextBand.afternoon;
    if (hour < 22) return ContextBand.evening;
    return ContextBand.night;
  }

  SkinId skinForContext(PlayContext ctx) {
    if (ctx.isDarkHour) return SkinId.abyss;

    if (ctx.raining) return SkinId.amber;

    switch (ctx.band) {
      case ContextBand.morning:
      case ContextBand.afternoon:
        return SkinId.amber;
      case ContextBand.evening:
        return SkinId.abyss;
      case ContextBand.night:
        return SkinId.crimson;
      case ContextBand.darkHour:
        return SkinId.abyss;
    }
  }

  SkinId resolve({
    required PlayContext ctx,
    required SkinPreference pref,
    PlayContext? previousCtx,
  }) {
    final contextual = skinForContext(ctx);

    if (!pref.isManual) return contextual;

    final bandChanged = previousCtx != null && previousCtx.band != ctx.band;
    if (bandChanged) return contextual;

    return pref.manualSkin!;
  }
}
