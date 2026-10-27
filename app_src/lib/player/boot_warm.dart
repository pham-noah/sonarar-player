library;

import '../art/skin_art.dart';

const int kPlayerArtDecodeWidth = 900;

const int kHeaderArtDecodeWidth = 1080;

List<SkinArt> artToWarmBeforeGate({
  required List<SkinArt> pieces,
  required SkinArt? current,
}) {
  if (current == null) return const [];
  return [current];
}

List<SkinArt> artToWarmAfterGate({
  required List<SkinArt> pieces,
  required SkinArt? current,
}) {
  final skip = current?.assetPath;
  return [
    for (final piece in pieces)
      if (piece.assetPath != skip) piece,
  ];
}
