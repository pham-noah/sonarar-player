library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/main.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';
import 'package:sonarar/theme/slab.dart';
import 'package:sonarar/theme/surface.dart';

import 'shell_probe.dart';

const _storage = MethodChannel('personar/storage');
late Directory _sandbox;

void _fakePlatform() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => call.method.startsWith('get') ? _sandbox.path : null,
  );
  messenger.setMockMethodCallHandler(_storage, (call) async {
    switch (call.method) {
      case 'status':
      case 'request':
      case 'requestNotification':
        return 'granted';
      default:
        return null;
    }
  });
  for (final name in const [
    'dev.fluttercommunity.plus/wakelock',
    'com.lykone.location',
    'com.ryanheise.just_audio_background',
    'personar/geofence',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name),
        (call) async => null);
  }
}

Future<int> _sharpPixels(
  WidgetTester tester, {
  required int yFrom,
  required int yTo,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
      RepaintBoundary(key: key, child: const SonararApp()));
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  try {
    HomeShellStateProbe.shellCall(tester, 'debugFinishLoading');
  } on Object {
    // ignore: empty_catches
  }
  final dynamic app = HomeShellStateProbe.appStateOf(tester);
  // ignore: avoid_dynamic_calls
  app.setLayout(LayoutKind.glass);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }

  expect(find.byType(BackdropFilter), findsOneWidget,
      reason: 'the glass bar has no filter — this raster cannot say anything about its bounds');

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
  final rgba = bytes!.buffer.asUint8List();
  final width = image!.width;
  final height = image.height;

  double luma(int x, int y) {
    final i = (y * width + x) * 4;
    return 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
  }

  var sharp = 0;
  for (var y = yFrom; y < yTo && y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final c = 4 * luma(x, y) -
          luma(x - 1, y) -
          luma(x + 1, y) -
          luma(x, y - 1) -
          luma(x, y + 1);
      if (c.abs() > 40) sharp++;
    }
  }
  // ignore: avoid_print
  print('GLASS RASTER ${width}x$height rows $yFrom-$yTo: sharp=$sharp');
  return sharp;
}

void main() {
  setUp(() {
    _sandbox = Directory.systemTemp.createTempSync('personar-glass-bounds-');
    _fakePlatform();
  });
  tearDown(() {
    if (_sandbox.existsSync()) _sandbox.deleteSync(recursive: true);
  });

  testWidgets('the page behind the glass bars keeps its edges', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sharp = await _sharpPixels(tester, yFrom: 40, yTo: 520);

    expect(sharp, greaterThan(500),
        reason: 'the content region has no edges left — the glass is blurring the page, not the pane');
  });

  testWidgets('and the pane itself still frosts what is behind it',
      (tester) async {
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    const pane = Rect.fromLTWH(100, 150, 120, 100);

    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _Stripes())),
            Positioned.fromRect(
              rect: pane,
              child: Surface(

                presentation: presentationFor(
                    LayoutKind.glass, skinFor(SkinId.values.first)),
                role: SurfaceRole.bar,
                radius: 12,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
    final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    final rgba = bytes!.buffer.asUint8List();
    final width = image!.width;

    double luma(int x, int y) {
      final i = (y * width + x) * 4;
      return 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
    }

    double step(Rect r) {
      var sum = 0.0;
      var n = 0;
      for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
        for (var x = r.left.toInt() + 1; x < r.right.toInt(); x++) {
          sum += (luma(x, y) - luma(x - 1, y)).abs();
          n++;
        }
      }
      return n == 0 ? 0 : sum / n;
    }

    final inside = step(pane.deflate(12));
    final outside = step(const Rect.fromLTWH(20, 40, 60, 60));
    // ignore: avoid_print
    print('GLASS PANE inside=$inside outside=$outside');

    expect(outside, greaterThan(15),
        reason: 'the stripes beside the pane are not sharp — the fixture is wrong, not the app');
    expect(inside, lessThan(3),
        reason: 'the pane is not frosting its own backdrop — the glass lost its blur, not its bounds');
  });

  testWidgets('a SCREEN full of glass cards bounds every one of them',
      (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    final skin = skinFor(SkinId.values.first);

    const top = 20.0;
    const cardH = 56.0;
    const gap = 22.0;
    const left = 16.0;

    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _Stripes())),
            for (var i = 0; i < 5; i++)
              Positioned(
                left: left,
                right: left,
                top: top + i * (cardH + gap),
                height: cardH,
                child: Slab(
                  skin: skin,
                  presentation: presentationFor(LayoutKind.glass, skin),
                  radius: 12,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
    final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    final rgba = bytes!.buffer.asUint8List();
    final width = image!.width;

    double luma(int x, int y) {
      final i = (y * width + x) * 4;
      return 0.2126 * rgba[i] + 0.7152 * rgba[i + 1] + 0.0722 * rgba[i + 2];
    }

    double step(Rect r) {
      var sum = 0.0;
      var n = 0;
      for (var y = r.top.toInt(); y < r.bottom.toInt(); y++) {
        for (var x = r.left.toInt() + 1; x < r.right.toInt(); x++) {
          sum += (luma(x, y) - luma(x - 1, y)).abs();
          n++;
        }
      }
      return n == 0 ? 0 : sum / n;
    }

    final betweenCards =
        Rect.fromLTWH(left + 20, top + cardH + 5, 360 - 2 * left - 40, gap - 10);
    final insideCard =
        Rect.fromLTWH(left + 20, top + 5, 360 - 2 * left - 40, cardH - 10);

    final gapStep = step(betweenCards);
    final cardStep = step(insideCard);
    // ignore: avoid_print
    print('GLASS LIST: between=$gapStep insideCard=$cardStep');

    expect(gapStep, greaterThan(15),
        reason: 'the gaps between the cards lost their stripes — one of the filters is not bounded to '
            'its card, so the page is being blurred by the list');
    expect(cardStep, lessThan(3),
        reason: 'a card is not frosting its own backdrop — the material lost its blur');
  });
}

class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var x = 0.0; x < size.width; x += 8) {
      p.color = x ~/ 8 % 2 == 0
          ? const Color(0xFF101010)
          : const Color(0xFFF0F0F0);
      canvas.drawRect(Rect.fromLTWH(x, 0, 8, size.height), p);
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}
