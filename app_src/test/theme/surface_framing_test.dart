import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/personalization.dart';

/// A place's picture is framed once, where it was put. These pin that the
/// framing is stored, survives a save/load round trip, and that the place uses
/// it instead of the default's.
void main() {
  const framed = BackdropSpec(
    file: 'room.jpg',
    focusX: 0.2,
    focusY: 0.8,
    scale: 3,
    rotationDeg: 12,
    blur: 4,
    dim: 0.1,
    grain: 0.3,
    vignette: 0.4,
    burn: 0.5,
    saturation: 1.2,
    contrast: 0.9,
  );

  test('a place keeps the framing it was given', () {
    final p = const Personalization().withSurface(
      SurfaceId.library,
      const SurfaceLook(room: 'room.jpg', spec: framed),
    );
    final spec = p.backdropFor(SurfaceId.library);
    expect(spec.focusX, 0.2);
    expect(spec.scale, 3);
    expect(spec.rotationDeg, 12);
  });

  test('the framing survives saving and loading', () {
    final p = const Personalization().withSurface(
      SurfaceId.library,
      const SurfaceLook(room: 'room.jpg', spec: framed),
    );
    final back = Personalization.decode(p.encode());
    final spec = back.backdropFor(SurfaceId.library);
    expect(spec.focusX, closeTo(0.2, 1e-9));
    expect(spec.scale, closeTo(3, 1e-9));
    expect(spec.grain, closeTo(0.3, 1e-9));
    expect(spec.burn, closeTo(0.5, 1e-9));
  });

  test('an unset place still inherits the default framing', () {
    const p = Personalization(backdrop: framed);
    final spec = p.backdropFor(SurfaceId.home);
    expect(spec.focusX, 0.2);
    expect(spec.scale, 3);
  });

  test('the zoom ceiling is the ceiling everywhere', () {
    const spec = BackdropSpec(file: 'a.jpg', scale: 6);
    expect(BackdropSpec.fromJson(jsonDecode(jsonEncode(spec.toJson()))).scale, 6);
    expect(spec.copyWith(scale: 9).scale, BackdropSpec.maxScale);
  });

  test('a cleared place paints nothing of its own', () {
    const p = Personalization(
      backdrop: BackdropSpec(file: 'default.jpg', focusX: 0.1),
    );
    final withStale = p.withSurface(SurfaceId.library, const SurfaceLook());
    expect(withStale.surfaces, isEmpty);
  });

  test('art keys survive a round trip too', () {
    const spec = BackdropSpec(artKey: 'makoto/frame-2.png', followTrack: true);
    final back = BackdropSpec.fromJson(jsonDecode(jsonEncode(spec.toJson())));
    expect(back.artKey, 'makoto/frame-2.png');
  });
}
