library;

enum WeatherCondition {
  unknown,
  clear,
  clouds,
  fog,
  drizzle,
  rain,
  snow,
  thunder,
}

WeatherCondition conditionForWmoCode(int code) {
  switch (code) {
    case 0:
      return WeatherCondition.clear;
    case 1:
    case 2:
    case 3:
      return WeatherCondition.clouds;
    case 45:
    case 48:
      return WeatherCondition.fog;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return WeatherCondition.drizzle;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return WeatherCondition.rain;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return WeatherCondition.snow;
    case 95:
    case 96:
    case 99:
      return WeatherCondition.thunder;
    default:
      return WeatherCondition.unknown;
  }
}

extension WeatherConditionWetness on WeatherCondition {
  bool get isWet =>
      this == WeatherCondition.rain ||
      this == WeatherCondition.drizzle ||
      this == WeatherCondition.thunder;
}

String labelFor(WeatherCondition c) => switch (c) {
      WeatherCondition.unknown => 'unknown',
      WeatherCondition.clear => 'clear',
      WeatherCondition.clouds => 'clouds',
      WeatherCondition.fog => 'fog',
      WeatherCondition.drizzle => 'drizzle',
      WeatherCondition.rain => 'rain',
      WeatherCondition.snow => 'snow',
      WeatherCondition.thunder => 'thunder',
    };
