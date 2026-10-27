library;

import 'package:flutter/material.dart';

import 'weather_codes.dart';
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

String weatherName(WeatherCondition condition) => switch (condition) {
      WeatherCondition.clear => 'CLEAR',
      WeatherCondition.clouds => 'OVERCAST',
      WeatherCondition.fog => 'FOG',
      WeatherCondition.drizzle => 'DRIZZLE',
      WeatherCondition.rain => 'RAIN',
      WeatherCondition.snow => 'SNOW',
      WeatherCondition.thunder => 'STORM',
      WeatherCondition.unknown => 'NO READING',
    };
