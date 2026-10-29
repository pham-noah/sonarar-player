import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_spec.dart';

/// Framing belongs to the picture and is stored next to it.
void main() {
  test('a spec that says nothing is the untouched picture', () {
    expect(const ArtSpec().isDefault, isTrue);
    expect(ArtSpec.fromJson(null).isDefault, isTrue);
    expect(ArtSpec.fromJson({'nonsense': 1}).isDefault, isTrue,
        reason: 'a broken spec must not throw on launch');
  });

  test('every value is clamped, so art cannot be dragged out of its frame', () {
    final spec = const ArtSpec().copyWith(
      dx: 9,
      dy: -9,
      zoom: 40,
      rotationDeg: 400,
      fade: 4,
    );

    expect(spec.dx, 1);
    expect(spec.dy, -1);
    expect(spec.zoom, ArtSpec.maxZoom);
    expect(spec.rotationDeg, ArtSpec.maxRotation);
    expect(spec.fade, 1);
  });

  test('zoom can never go below fitting the frame', () {
    expect(const ArtSpec().copyWith(zoom: 0.2).zoom, ArtSpec.minZoom);
  });

  test('a spec survives the file it is written to', () {
    final dir = Directory.systemTemp.createTempSync('sonarar-art');
    addTearDown(() => dir.deleteSync(recursive: true));

    const spec = ArtSpec(dx: 0.25, dy: -0.5, zoom: 1.6, rotationDeg: -7, flipX: true, fade: 0.4);
    ArtSpec.write(dir, spec);
    final back = ArtSpec.read(dir);

    expect(back.dx, 0.25);
    expect(back.dy, -0.5);
    expect(back.zoom, 1.6);
    expect(back.rotationDeg, -7);
    expect(back.flipX, isTrue);
    expect(back.fade, 0.4);
  });

  test('saving the default deletes the file instead of storing nothing', () {
    final dir = Directory.systemTemp.createTempSync('sonarar-art');
    addTearDown(() => dir.deleteSync(recursive: true));

    ArtSpec.write(dir, const ArtSpec(zoom: 1.4));
    expect(ArtSpec.fileFor(dir).existsSync(), isTrue);

    ArtSpec.write(dir, ArtSpec.none);
    expect(ArtSpec.fileFor(dir).existsSync(), isFalse);
    expect(ArtSpec.read(dir).isDefault, isTrue);
  });

  test('a bundle with no spec file reads as untouched art', () {
    final dir = Directory.systemTemp.createTempSync('sonarar-art');
    addTearDown(() => dir.deleteSync(recursive: true));

    expect(ArtSpec.read(dir).isDefault, isTrue);
  });

  test('the placement keeps the picture inside the frame it was given', () {
    final place = const ArtSpec(dx: 0.5, dy: -0.5).place(200, 100);

    expect(place.tx, 50, reason: 'half a frame width to the right');
    expect(place.ty, -25);
    expect(place.scale, 1);
    expect(place.angle, 0);
  });

  test('rotation is converted once, in one place', () {
    final place = const ArtSpec(rotationDeg: 15).place(100, 100);
    expect(place.angle, closeTo(0.2618, 0.0001));
  });
}
