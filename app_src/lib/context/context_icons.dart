library;

import 'package:flutter/material.dart';

import 'weather_codes.dart';
import '../l10n/app_localizations.dart';
import '../theme/skin_policy.dart';

IconData bandIcon(ContextBand? band) => switch (band) {
      ContextBand.morning => Icons.wb_twilight_rounded,
      ContextBand.afternoon => Icons.wb_sunny_rounded,
      ContextBand.evening => Icons.nights_stay_rounded,
      ContextBand.night => Icons.dark_mode_rounded,
      ContextBand.darkHour => Icons.nightlight_round,
      null => Icons.hourglass_empty_rounded,
    };

IconData? weatherIcon(WeatherCondition condition) => switch (condition) {
      WeatherCondition.clear => Icons.sunny,
      WeatherCondition.clouds => Icons.cloud_rounded,
      WeatherCondition.fog => Icons.foggy,
      WeatherCondition.drizzle => Icons.grain_rounded,
      WeatherCondition.rain => Icons.water_drop_rounded,
      WeatherCondition.snow => Icons.ac_unit_rounded,
      WeatherCondition.thunder => Icons.thunderstorm_rounded,
      WeatherCondition.unknown => null,
    };

String weatherName(AppLocalizations l10n, WeatherCondition condition) =>
    switch (condition) {
      WeatherCondition.clear => l10n.weatherClear,
      WeatherCondition.clouds => l10n.weatherOvercast,
      WeatherCondition.fog => l10n.weatherFog,
      WeatherCondition.drizzle => l10n.weatherDrizzle,
      WeatherCondition.rain => l10n.weatherRain,
      WeatherCondition.snow => l10n.weatherSnow,
      WeatherCondition.thunder => l10n.weatherStorm,
      WeatherCondition.unknown => l10n.weatherNoReading,
    };
