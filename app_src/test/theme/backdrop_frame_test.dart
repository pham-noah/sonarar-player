import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/backdrop_layer.dart';

/// The editor and the runtime draw a picture through the same function, so these
/// assertions hold for both: if the picture follows the finger here, it follows
/// it on the phone, and what you frame is what you get.
void main() {
  Transform translateOf(Widget w) {
    final rotate = w as Transform;
    return rotate.child! as Transform;
  }

  test('a picture at 1x still has room to move', () {
    final w = PersonalBackdrop.frame(
      child: const SizedBox(),
      size: const Size(200, 100),
      scale: 1,
      rotationDeg: 0,
      focusX: 1,
      focusY: 1,
    );
    final t = translateOf(w).transform.getTranslation();
    // 1.25 overscan on 200 wide leaves 25px each side.
    expect(t.x, closeTo(-25, 0.01));
    expect(t.y, closeTo(-12.5, 0.01));
  });

  test('the picture follows the finger, not against it', () {
    final w = PersonalBackdrop.frame(
      child: const SizedBox(),
      size: const Size(200, 200),
      scale: 1,
      rotationDeg: 0,
      // Dragging right lowers the focus by dx / width.
      focusX: 0.5 - 20 / 200,
      focusY: 0.5,
    );
    final t = translateOf(w).transform.getTranslation();
    expect(t.x, greaterThan(0), reason: 'drag right must move the picture right');
  });

  test('framing is symmetric around the centre', () {
    double dx(double focus) => translateOf(
      PersonalBackdrop.frame(
        child: const SizedBox(),
        size: const Size(200, 200),
        scale: 2,
        rotationDeg: 0,
        focusX: focus,
        focusY: 0.5,
      ),
    ).transform.getTranslation().x;

    expect(dx(0.5), closeTo(0, 0.01));
    expect(dx(0) + dx(1), closeTo(0, 0.01));
  });

  test('rotation earns more room, never less', () {
    double dx(double deg) => translateOf(
      PersonalBackdrop.frame(
        child: const SizedBox(),
        size: const Size(200, 200),
        scale: 1,
        rotationDeg: deg,
        focusX: 1,
        focusY: 0.5,
      ),
    ).transform.getTranslation().x.abs();

    expect(dx(45), greaterThan(dx(0)));
  });
}
