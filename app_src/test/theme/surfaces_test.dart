import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/personalization.dart';

/// Each place may wear its own picture, and a place with none inherits.
void main() {
  const defaultPhoto = BackdropSpec(file: 'room.jpg', blur: 4, dim: 0.5);

  test('a place without its own picture wears the default', () {
    const p = Personalization(backdrop: defaultPhoto);

    expect(p.backdropFor(SurfaceId.library).file, 'room.jpg');
    expect(p.backdropFor(SurfaceId.library).blur, 4,
        reason: 'the inherited picture lost its framing');
  });

  test('a place with its own picture wears that one, framed the same way', () {
    const p = Personalization(
      backdrop: defaultPhoto,
      surfaces: {SurfaceId.player: SurfaceLook(room: 'stage.jpg')},
    );

    expect(p.backdropFor(SurfaceId.player).file, 'stage.jpg');
    expect(p.backdropFor(SurfaceId.player).dim, 0.5);
    expect(p.backdropFor(SurfaceId.home).file, 'room.jpg',
        reason: 'one place setting a picture changed another');
  });

  test('it survives a round trip through the theme file', () {
    const p = Personalization(
      accent: AccentSpec(source: AccentSource.manual, value: 0xFF00E5A0),
      surfaces: {
        SurfaceId.search: SurfaceLook(room: 'night.jpg'),
        SurfaceId.player: SurfaceLook(art: 'bundle/frame.png'),
      },
    );

    final restored = Personalization.decode(p.encode());

    expect(restored.surfaces[SurfaceId.search]?.room, 'night.jpg');
    expect(restored.surfaces[SurfaceId.player]?.art, 'bundle/frame.png');
    expect(restored.accent.value, 0xFF00E5A0);
  });

  test('clearing a place drops the entry instead of storing an empty one', () {
    const p = Personalization(
      surfaces: {SurfaceId.home: SurfaceLook(room: 'a.jpg')},
    );

    final cleared = p.withSurface(SurfaceId.home, const SurfaceLook());

    expect(cleared.surfaces, isEmpty);
    expect(cleared.isDefault, isTrue);
  });

  test('an unknown place name in an old file is ignored, not fatal', () {
    final restored = Personalization.decode(
      '{"surfaces":{"kitchen":{"room":"a.jpg"},"home":{"room":"b.jpg"}}}',
    );

    expect(restored.surfaces.length, 1);
    expect(restored.surfaces[SurfaceId.home]?.room, 'b.jpg');
  });
}
