library;

import 'package:jp_transliterate/jp_transliterate.dart';
import 'package:korean_romanization_converter/korean_romanization_converter.dart';

class Romaji {
  const Romaji._();

  static final _korean = KoreanRomanizationConverter();

  static bool isJapanese(String s) {
    for (final r in s.runes) {
      if ((r >= 0x3040 && r <= 0x30FF) || (r >= 0x4E00 && r <= 0x9FFF)) return true;
    }
    return false;
  }

  static bool isKorean(String s) {
    for (final r in s.runes) {
      if ((r >= 0xAC00 && r <= 0xD7AF) ||
          (r >= 0x1100 && r <= 0x11FF) ||
          (r >= 0x3130 && r <= 0x318F)) {
        return true;
      }
    }
    return false;
  }

  static bool needs(String s) => isJapanese(s) || isKorean(s);

  static String korean(String s) {
    try {
      return _korean.romanize(s);
    } catch (_) {
      return s;
    }
  }

  static Future<String?> japanese(String s) async {
    try {
      final data = await JpTransliterate.transliterate(kanji: s);
      final romaji = data.romaji.trim();
      if (romaji.isEmpty) return null;

      if (romaji == s.trim()) return null;
      return romaji;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<int, String>> precompute(List<String> lines) async {
    final out = <int, String>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!needs(line)) continue;
      if (isKorean(line)) {
        final r = korean(line);
        if (r.trim().isNotEmpty) out[i] = r;
        continue;
      }

      final r = await japanese(line);
      if (r != null) out[i] = r;
    }
    return out;
  }
}
