library;

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

  /// Kana are romanised here; kanji are left exactly as they are.
  ///
  /// Reading kanji aloud needs a morphological dictionary, and the one kuromoji
  /// ships is 32 MB — more than a third of the APK — for a feature that only
  /// applies to Japanese lyric sheets. Kana covers most chorus lines; 東京 stays
  /// 東京 instead of becoming toukyou. That is the trade.
  static Future<String?> japanese(String s) async {
    final romaji = _kana(s).trim();
    if (romaji.isEmpty || romaji == s.trim()) return null;
    if (!RegExp('[A-Za-z]').hasMatch(romaji)) return null;
    return romaji;
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

  static String _kana(String s) {
    final out = StringBuffer();
    var geminate = false;
    String? lastVowel;

    for (var i = 0; i < s.length; i++) {
      final ch = _hiragana(s[i]);

      if (ch == 'っ') {
        geminate = true;
        continue;
      }
      if (ch == 'ー') {
        if (lastVowel != null) out.write(lastVowel);
        continue;
      }

      String? piece;
      if (i + 1 < s.length) {
        piece = _digraphs[ch + _hiragana(s[i + 1])];
        if (piece != null) i++;
      }
      piece ??= _mono[ch];

      if (piece == null) {
        out.write(ch);
        geminate = false;
        lastVowel = null;
        continue;
      }

      if (geminate) {
        piece = piece.startsWith('ch') ? 't$piece' : '${piece[0]}$piece';
        geminate = false;
      }

      if (piece == 'n' && i + 1 < s.length) {
        final next = _hiragana(s[i + 1]);
        if (_vowels.contains(next) || 'ゃゅょ'.contains(next)) piece = "n'";
      }

      out.write(piece);
      lastVowel = _vowels.contains(piece[piece.length - 1])
          ? piece[piece.length - 1]
          : null;
    }
    return out.toString();
  }

  static String _hiragana(String ch) {
    final code = ch.codeUnitAt(0);
    if (code >= 0x30A1 && code <= 0x30F6) {
      return String.fromCharCode(code - 0x60);
    }
    return ch;
  }

  static const _vowels = 'aeiou';

  static const _mono = <String, String>{
    'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
    'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
    'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
    'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
    'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
    'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
    'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
    'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
    'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
    'わ': 'wa', 'ゐ': 'wi', 'ゑ': 'we', 'を': 'wo', 'ん': 'n',
    'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
    'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
    'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
    'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
    'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
    'ゔ': 'vu',
    'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o',
    'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'ゎ': 'wa',
  };

  static const _digraphs = <String, String>{
    'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
    'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho',
    'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho',
    'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
    'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
    'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
    'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
    'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
    'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo',
    'ぢゃ': 'ja', 'ぢゅ': 'ju', 'ぢょ': 'jo',
    'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
    'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
  };
}
