library;

import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/skin_policy.dart';

SkinId? skinFromPrefs(String? raw) {
  if (raw == null) return null;
  for (final s in kAllSkins) {
    if (s.id.name == raw) return s.id;
  }
  return null;
}

LayoutKind layoutFromPrefs(String raw) => switch (raw) {
      'solid' => LayoutKind.solid,
      'glass' => LayoutKind.glass,
      _ => LayoutKind.sonar,
    };

String? bandNameOf(ContextBand? band) => switch (band) {
      ContextBand.darkHour => 'NIGHT HOUR',
      ContextBand.morning => 'MORNING',
      ContextBand.afternoon => 'AFTERNOON',
      ContextBand.evening => 'EVENING',
      ContextBand.night => 'NIGHT',
      null => null,
    };
