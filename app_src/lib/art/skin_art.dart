library;

import '../art/art_focus.dart';
import '../theme/skin.dart';

class SkinArt {
  const SkinArt({
    required this.key,
    required this.assetPath,
    required this.aspect,
    this.focus = ArtFocus.centre,
    this.fullBleed = false,
  });

  final String key;

  final String assetPath;

  final double aspect;

  final ArtFocus focus;

  final bool fullBleed;
}

class SkinArtSet {
  const SkinArtSet(this.skinId, this.pieces);

  final SkinId skinId;
  final List<SkinArt> pieces;

  bool get hasArt => pieces.isNotEmpty;

  SkinArt? get defaultArt => pieces.isEmpty ? null : pieces.first;

  int get length => pieces.length;

  int nextIndex(int current) {
    if (pieces.isEmpty) return 0;
    final normalised = current % pieces.length;
    return (normalised + 1) % pieces.length;
  }

  int previousIndex(int current) {
    if (pieces.isEmpty) return 0;
    final normalised = current % pieces.length;
    return (normalised - 1 + pieces.length) % pieces.length;
  }

  SkinArt? atOrNull(int index) {
    if (pieces.isEmpty) return null;
    return pieces[index % pieces.length];
  }

  int indexOfKey(String key) {
    if (key.isEmpty) return -1;
    return pieces.indexWhere((p) => p.key == key);
  }

  SkinArt? byKey(String key) {
    final at = indexOfKey(key);
    return at < 0 ? null : pieces[at];
  }
}

const SkinArtSet kArtAbyss = SkinArtSet(SkinId.abyss, [
  SkinArt(key: 'makoto', assetPath: 'assets/art/abyss/makoto.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.56)),
  SkinArt(key: 'yukari', assetPath: 'assets/art/abyss/yukari.png', aspect: 1920 / 1080, focus: ArtFocus(dx: -0.44)),
  SkinArt(key: 'junpei', assetPath: 'assets/art/abyss/junpei.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.42)),
  SkinArt(key: 'aigis', assetPath: 'assets/art/abyss/aigis.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.46)),
  SkinArt(key: 'mitsuru', assetPath: 'assets/art/abyss/mitsuru.png', aspect: 1920 / 1080, focus: ArtFocus(dx: -0.56)),
  SkinArt(key: 'akihiko', assetPath: 'assets/art/abyss/akihiko.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.50)),
  SkinArt(key: 'ken', assetPath: 'assets/art/abyss/ken.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.24)),
  SkinArt(key: 'shinjiro', assetPath: 'assets/art/abyss/shinjiro.png', aspect: 1920 / 1080, focus: ArtFocus(dx: -0.04)),
  SkinArt(key: 'koromaru', assetPath: 'assets/art/abyss/koromaru.png', aspect: 1920 / 1080, focus: ArtFocus(dx: 0.10)),
]);

const SkinArtSet kArtAmber = SkinArtSet(SkinId.amber, [
  SkinArt(key: 'menu_01_gold', assetPath: 'assets/art/amber/menu_01_gold.jpg', aspect: 1920 / 1080, fullBleed: true),
  SkinArt(key: 'menu_02_tangerine', assetPath: 'assets/art/amber/menu_02_tangerine.jpg', aspect: 1920 / 1080, fullBleed: true),
  SkinArt(key: 'menu_03_spring_green', assetPath: 'assets/art/amber/menu_03_spring_green.jpg', aspect: 1920 / 1080, fullBleed: true),
  SkinArt(key: 'menu_04_blood_red', assetPath: 'assets/art/amber/menu_04_blood_red.jpg', aspect: 1920 / 1080, fullBleed: true),
]);

const SkinArtSet kArtCrimson = SkinArtSet(SkinId.crimson, [
  SkinArt(key: 'joker', assetPath: 'assets/art/crimson/joker.png', aspect: 1500 / 1250, focus: ArtFocus(dy: 0.16)),
  SkinArt(key: 'skull', assetPath: 'assets/art/crimson/skull.png', aspect: 1500 / 1250, focus: ArtFocus(dx: -0.25, dy: 0.20)),
  SkinArt(key: 'panther', assetPath: 'assets/art/crimson/panther.png', aspect: 1500 / 1250),
  SkinArt(key: 'fox', assetPath: 'assets/art/crimson/fox.png', aspect: 1500 / 1250, focus: ArtFocus(dx: -0.33, dy: 0.34)),
  SkinArt(key: 'queen', assetPath: 'assets/art/crimson/queen.png', aspect: 1500 / 1250, focus: ArtFocus(dx: 0.20, dy: 0.34)),
  SkinArt(key: 'oracle', assetPath: 'assets/art/crimson/oracle.png', aspect: 1500 / 1250, focus: ArtFocus(dy: 0.40)),
  SkinArt(key: 'noir', assetPath: 'assets/art/crimson/noir.png', aspect: 1500 / 1250, focus: ArtFocus(dx: -0.20, dy: -0.20)),
  SkinArt(key: 'crow', assetPath: 'assets/art/crimson/crow.png', aspect: 1500 / 1247, focus: ArtFocus(dy: 0.34)),
  SkinArt(key: 'mona', assetPath: 'assets/art/crimson/mona.png', aspect: 1500 / 1250, focus: ArtFocus(dx: 0.33)),
]);

const List<SkinArtSet> kAllArtSets = [];

SkinArtSet artFor(SkinId id) => kAllArtSets.firstWhere(
      (a) => a.skinId == id,
      orElse: () => SkinArtSet(id, const []),
    );

Iterable<SkinArt> get kAllArtPieces =>
    kAllArtSets.expand((set) => set.pieces);
