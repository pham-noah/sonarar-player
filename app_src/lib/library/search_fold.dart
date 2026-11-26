/// What a search compares, once the accents are gone.
///
/// Searching for "bjork" found nothing in a library full of Björk, and "sigur
/// ros" found nothing under Sigur Rós. The box lower-cased both sides and
/// stopped there, which is fine for English titles and useless for a music
/// library: most of the world's names carry a mark the person typing does not
/// have on their keyboard, and nobody reaches for a diacritic mid-song.
///
/// So both the query and the haystack pass through here. Folding both is what
/// makes it symmetrical — "björk" typed with the mark still finds a file tagged
/// "Bjork", and "bjork" typed without it still finds Björk.
///
/// The table is Latin-1 plus Latin Extended-A because those are the marks that
/// arrive on a phone's own keyboard. It is not a transliterator: CJK, Cyrillic
/// and Greek pass through untouched, and finding 宇多田ヒカル from a Latin
/// keyboard is what the `romaji` field on a track is for. Full-width Latin
/// (ＡＢＣ, what an IME produces by accident) is folded to ASCII, because those
/// look identical to the user and are not.
library;

const Map<int, String> _foldings = {
  0x00E0: 'a', 0x00E1: 'a', 0x00E2: 'a', 0x00E3: 'a', 0x00E4: 'a', 0x00E5: 'a',
  0x0101: 'a', 0x0103: 'a', 0x0105: 'a',
  0x00E7: 'c', 0x0107: 'c', 0x0109: 'c', 0x010B: 'c', 0x010D: 'c',
  0x010F: 'd', 0x0111: 'd', 0x00F0: 'd',
  0x00E8: 'e', 0x00E9: 'e', 0x00EA: 'e', 0x00EB: 'e', 0x0113: 'e', 0x0117: 'e',
  0x0119: 'e', 0x011B: 'e',
  0x011D: 'g', 0x011F: 'g', 0x0121: 'g', 0x0123: 'g',
  0x0125: 'h', 0x0127: 'h',
  0x00EC: 'i', 0x00ED: 'i', 0x00EE: 'i', 0x00EF: 'i', 0x0129: 'i', 0x012B: 'i',
  0x012D: 'i', 0x012F: 'i', 0x0131: 'i', 0x0133: 'ij',
  0x0135: 'j', 0x0137: 'k',
  0x013A: 'l', 0x013C: 'l', 0x013E: 'l', 0x0142: 'l',
  0x00F1: 'n', 0x0144: 'n', 0x0146: 'n', 0x0148: 'n', 0x0149: 'n',
  0x00F2: 'o', 0x00F3: 'o', 0x00F4: 'o', 0x00F5: 'o', 0x00F6: 'o', 0x00F8: 'o',
  0x014D: 'o', 0x014F: 'o', 0x0151: 'o', 0x0153: 'oe',
  0x0155: 'r', 0x0157: 'r', 0x0159: 'r',
  0x015B: 's', 0x015D: 's', 0x015F: 's', 0x0161: 's', 0x00DF: 'ss',
  0x0163: 't', 0x0165: 't', 0x0167: 't', 0x00FE: 'th',
  0x00F9: 'u', 0x00FA: 'u', 0x00FB: 'u', 0x00FC: 'u', 0x0169: 'u', 0x016B: 'u',
  0x016D: 'u', 0x016F: 'u', 0x0171: 'u', 0x0173: 'u',
  0x0175: 'w', 0x00FD: 'y', 0x00FF: 'y', 0x0177: 'y',
  0x017A: 'z', 0x017C: 'z', 0x017E: 'z',
  // Full-width Latin and digits: an IME produces these and they read as ASCII.
  0xFF10: '0', 0xFF11: '1', 0xFF12: '2', 0xFF13: '3', 0xFF14: '4',
  0xFF15: '5', 0xFF16: '6', 0xFF17: '7', 0xFF18: '8', 0xFF19: '9',
  // Upper and lower: `toLowerCase()` maps Ｂ to ｂ, not to b, so the lowercase
  // range has to be in the table or a full-width query stays full-width.
  0xFF21: 'a', 0xFF22: 'b', 0xFF23: 'c', 0xFF24: 'd', 0xFF25: 'e',
  0xFF26: 'f', 0xFF27: 'g', 0xFF28: 'h', 0xFF29: 'i', 0xFF2A: 'j',
  0xFF2B: 'k', 0xFF2C: 'l', 0xFF2D: 'm', 0xFF2E: 'n', 0xFF2F: 'o',
  0xFF30: 'p', 0xFF31: 'q', 0xFF32: 'r', 0xFF33: 's', 0xFF34: 't',
  0xFF35: 'u', 0xFF36: 'v', 0xFF37: 'w', 0xFF38: 'x', 0xFF39: 'y',
  0xFF3A: 'z', 0xFF3B: '[', 0xFF3D: ']', 0xFF3E: '^', 0xFF3F: '_',
  0xFF41: 'a', 0xFF42: 'b', 0xFF43: 'c', 0xFF44: 'd', 0xFF45: 'e',
  0xFF46: 'f', 0xFF47: 'g', 0xFF48: 'h', 0xFF49: 'i', 0xFF4A: 'j',
  0xFF4B: 'k', 0xFF4C: 'l', 0xFF4D: 'm', 0xFF4E: 'n', 0xFF4F: 'o',
  0xFF50: 'p', 0xFF51: 'q', 0xFF52: 'r', 0xFF53: 's', 0xFF54: 't',
  0xFF55: 'u', 0xFF56: 'v', 0xFF57: 'w', 0xFF58: 'x', 0xFF59: 'y',
  0xFF5A: 'z',
  0xFF40: '`', 0xFF20: '@', 0xFF01: '!', 0xFF02: '"', 0xFF03: '#',
  0xFF04: r'$', 0xFF05: '%', 0xFF06: '&', 0xFF07: "'", 0xFF08: '(',
  0xFF09: ')', 0xFF0A: '*', 0xFF0B: '+', 0xFF0C: ',', 0xFF0D: '-',
  0xFF0E: '.', 0xFF0F: '/', 0xFF1A: ':', 0xFF1B: ';', 0xFF1C: '<',
  0xFF1D: '=', 0xFF1F: '?', 0xFF5B: '{', 0xFF5D: '}', 0xFF5C: '|',
  0xFF5E: '~', 0x3000: ' ',
};

/// Lower-cased, marks removed — the form the library's search box compares
/// against.
///
/// Not to be confused with `foldForSearch` in `youtube_search_screen.dart`,
/// which removes punctuation because YouTube match is a phrase match. A library
/// search must keep punctuation: `track_01.opus`, `re:zero` and `Svefn-g-englar`
/// are names, and folding a hyphen out of one makes it unfindable.
String foldForLibrarySearch(String input) {
  final lower = input.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final folded = _foldings[rune];
    if (folded != null) {
      out.write(folded);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Order two names the way a person reads them, not the way bytes sort.
///
/// `compareTo` on a lower-cased string puts every marked name after Z: Björk,
/// Motörhead and Sigur Rós all sat at the bottom of a list that begins with ABBA
/// and ends with ZZ Top, because ö (246) is greater than z (122). Folding first
/// puts them where their letters are, and the raw strings break the tie so two
/// names that fold alike (ABBA and abba) keep a fixed order instead of swapping
/// on every rebuild.
int compareFolded(String a, String b) {
  final fa = foldForLibrarySearch(a);
  final fb = foldForLibrarySearch(b);
  final byFolded = fa.compareTo(fb);
  return byFolded != 0 ? byFolded : a.compareTo(b);
}
