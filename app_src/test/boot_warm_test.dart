library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/art/skin_art.dart';
import 'package:sonarar/player/boot_warm.dart';
import 'package:sonarar/theme/skin.dart';

final SkinArtSet _fixture = SkinArtSet(SkinId.abyss, const [
  SkinArt(key: 'one', assetPath: 'assets/art/x/one.png', aspect: 1),
  SkinArt(key: 'two', assetPath: 'assets/art/x/two.png', aspect: 1),
  SkinArt(key: 'three', assetPath: 'assets/art/x/three.png', aspect: 1),
  SkinArt(key: 'four', assetPath: 'assets/art/x/four.png', aspect: 1),
  SkinArt(key: 'five', assetPath: 'assets/art/x/five.png', aspect: 1),
]);

void main() {
  final set = _fixture;

  test('the fixture has more than one piece, or this proves nothing', () {
    expect(set.pieces.length, greaterThan(1),
        reason: 'a one-piece skin cannot distinguish the two behaviours');
  });

  test('BEFORE the gate: only the current piece — never the whole set', () {
    final current = set.pieces[3];
    final before = artToWarmBeforeGate(pieces: set.pieces, current: current);

    expect(before, hasLength(1));
    expect(before.single.assetPath, current.assetPath);
    expect(before.length, lessThan(set.pieces.length),
        reason: 'the whole set is being warmed before the gate, which is the launch stall');
  });

  test('AFTER the gate: everything EXCEPT the current piece', () {
    final current = set.pieces[3];
    final after = artToWarmAfterGate(pieces: set.pieces, current: current);

    expect(after, hasLength(set.pieces.length - 1));
    expect(after.map((p) => p.assetPath), isNot(contains(current.assetPath)),
        reason: 'the current piece is already warm at its player size; warming it again is wasted work');
  });

  test('the two halves cover every piece exactly once', () {
    final current = set.pieces.first;
    final all = <String>{
      ...artToWarmBeforeGate(pieces: set.pieces, current: current).map((p) => p.assetPath),
      ...artToWarmAfterGate(pieces: set.pieces, current: current).map((p) => p.assetPath),
    };
    expect(all, set.pieces.map((p) => p.assetPath).toSet());

    final before = artToWarmBeforeGate(pieces: set.pieces, current: current).map((p) => p.assetPath).toList();
    final after = artToWarmAfterGate(pieces: set.pieces, current: current).map((p) => p.assetPath).toList();
    expect(before.toSet().intersection(after.toSet()), isEmpty,
        reason: 'a piece is warmed both before and after the gate');
  });

  test('no current piece warms NOTHING before the gate, and does not throw', () {
    expect(artToWarmBeforeGate(pieces: const [], current: null), isEmpty);
    expect(artToWarmAfterGate(pieces: const [], current: null), isEmpty);
  });

  test('the two widths are the ones the app actually paints at', () {
    expect(kPlayerArtDecodeWidth, 900);
    expect(kHeaderArtDecodeWidth, 1080);
  });
}
