library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/art/art_focus.dart';
import 'package:sonarar/widgets/framed_art.dart';

const _art = 'assets/brand/logo_mark.png';
const _aspect = 1.0;

const _size = Size(300, 200);

Widget _host(Widget art) => MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF04080F),
        body: Center(
          child: SizedBox(width: _size.width, height: _size.height, child: art),
        ),
      ),
    );

Widget _framed({required double opacity}) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: FramedArt(
        assetPath: _art,
        aspect: _aspect,
        focus: ArtFocus.centre,
        opacity: opacity,
      ),
    );

Widget _wrapped(double opacity) => RepaintBoundary(
      key: const ValueKey('shot'),
      child: Opacity(
        opacity: opacity,
        child: FramedArt(
          assetPath: _art,
          aspect: _aspect,
          focus: ArtFocus.centre,
        ),
      ),
    );

Future<List<int>> _pixels(WidgetTester tester) async {
  await tester.runAsync(() async {
    await precacheImage(const AssetImage(_art), tester.element(find.byType(FramedArt)));
  });
  await tester.pumpAndSettle();

  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));

  final data = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!;
  });
  return data!.buffer.asUint8List();
}

void main() {
  testWidgets('a dimmed picture is the SAME whether the alpha is in the image or in an Opacity wrapper',
      (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_framed(opacity: 0.62)));
    await tester.pumpAndSettle();
    final inImage = await _pixels(tester);

    await tester.pumpWidget(_host(_wrapped(0.62)));
    await tester.pumpAndSettle();
    final inWrapper = await _pixels(tester);

    expect(inImage.length, inWrapper.length, reason: 'the two renders are different sizes');

    for (final (name, px) in [('image alpha', inImage), ('Opacity wrapper', inWrapper)]) {
      final lit = <int>[];
      for (var i = 0; i < px.length; i += 4) {
        if (px[i] + px[i + 1] + px[i + 2] > 90) lit.add(i);
      }
      expect(lit.length, greaterThan(500),
          reason: 'the $name capture is blank, so comparing it proves nothing');
    }

    var worst = 0;
    var overTolerance = 0;
    for (var i = 0; i < inImage.length; i++) {
      final d = (inImage[i] - inWrapper[i]).abs();
      if (d > worst) worst = d;
      if (d > 4) overTolerance++;
    }
    // ignore: avoid_print
    print('BUDGET art opacity A/B: worst channel delta=$worst  pixels over tolerance=$overTolerance');

    expect(overTolerance, 0,
        reason: 'the two mechanisms draw DIFFERENT pictures at the same alpha — worst channel delta $worst');
  });

  testWidgets('and at FULL strength the image path is exactly the old render', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(_framed(opacity: 1.0)));
    await tester.pumpAndSettle();
    final a = await _pixels(tester);

    await tester.pumpWidget(_host(_wrapped(1.0)));
    await tester.pumpAndSettle();
    final b = await _pixels(tester);

    var worst = 0;
    for (var i = 0; i < a.length; i++) {
      final d = (a[i] - b[i]).abs();
      if (d > worst) worst = d;
    }
    // ignore: avoid_print
    print('BUDGET art opacity A/B at 1.0: worst channel delta=$worst');

    expect(worst, lessThanOrEqualTo(4),
        reason: 'full-strength art is not identical between the two paths — worst channel delta $worst');
  });
}
