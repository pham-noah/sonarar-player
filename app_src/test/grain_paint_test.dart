library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/backdrop_layer.dart';

/// Paints once into a throwaway recorder and returns it, so the test exercises
/// the same path a frame does.
ui.Picture _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  return recorder.endRecording();
}

void main() {
  setUp(debugForgetGrains);
  tearDown(debugForgetGrains);

  test('the same size records its grain once, not once per frame', () {
    final painter = debugGrainPainter(0.6);
    for (var frame = 0; frame < 40; frame++) {
      _paint(painter, const Size(400, 800)).dispose();
    }
    expect(debugRecordedGrains, 1,
        reason: 'the seeded speckle loop ran again for a size that was already '
            'recorded — thousands of random draws per frame for the same pixels');
  });

  test('a new size gets its own recording', () {
    final painter = debugGrainPainter(0.6);
    _paint(painter, const Size(400, 800)).dispose();
    _paint(painter, const Size(800, 400)).dispose();
    expect(debugRecordedGrains, 2,
        reason: 'a rotated backdrop would replay the landscape speckle over '
            'portrait pixels');
  });

  test('zero strength paints nothing and records nothing', () {
    final painter = debugGrainPainter(0);
    _paint(painter, const Size(400, 800)).dispose();
    expect(debugRecordedGrains, 0,
        reason: 'grain is off by default; a recording for it is wasted memory');
  });
}
