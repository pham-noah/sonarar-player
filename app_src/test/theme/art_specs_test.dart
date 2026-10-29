import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_spec.dart';
import 'package:sonarar/theme/personalization.dart';

/// Shipped art cannot carry a file, so its framing lives in the look file.
void main() {
  const key = 'abyss/first';

  test('framing written for a shipped picture comes back with the look', () {
    final p = const Personalization()
        .withArtSpec(key, const ArtSpec(zoom: 1.4, rotationDeg: -3));

    final restored = Personalization.decode(p.encode());

    expect(restored.specFor(key, ArtSpec.none).zoom, 1.4);
    expect(restored.specFor(key, ArtSpec.none).rotationDeg, -3);
  });

  test('a picture with no framing of its own keeps whatever it shipped with', () {
    const shipped = ArtSpec(zoom: 1.2);

    final p = const Personalization().withArtSpec(key, ArtSpec.none);

    expect(p.specFor('other/key', shipped).zoom, 1.2);
    expect(p.artSpecs, isEmpty, reason: 'nothing was stored for a cleared spec');
  });

  test('clearing the framing removes the entry instead of storing zeroes', () {
    final p = const Personalization()
        .withArtSpec(key, const ArtSpec(zoom: 2))
        .withArtSpec(key, ArtSpec.none);

    expect(p.artSpecs, isEmpty);
    expect(p.isDefault, isTrue);
  });

  test('framing for shipped art does not make the look non-default by accident',
      () {
    final p = const Personalization().withArtSpec(key, const ArtSpec(zoom: 1.5));

    expect(p.isDefault, isFalse);
    expect(p.accent, Personalization.defaults.accent);
    expect(p.home.toJson(), Personalization.defaults.home.toJson());
  });

  test('a look file written before framing existed still loads', () {
    final restored = Personalization.decode('{"accent":{"value":${0xFF00E5A0}}}');

    expect(restored.artSpecs, isEmpty);
    expect(restored.accent.value, 0xFF00E5A0);
  });
}
