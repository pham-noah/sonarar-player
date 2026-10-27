library;

double ducked(double userLevel, {double factor = 0.4}) =>
    (userLevel * factor).clamp(0.0, 1.0);

double restoredLevel(double userLevel) => userLevel.clamp(0.0, 1.0);
