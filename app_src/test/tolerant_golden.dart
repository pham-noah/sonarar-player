library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

class TolerantGoldenFileComparator extends GoldenFileComparator {
  TolerantGoldenFileComparator({
    required this.basePath,
    this.channelTolerance = 4,
    this.writeOnly = false,
  });

  final String basePath;

  final int channelTolerance;

  final bool writeOnly;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    if (writeOnly) {
      await update(golden, imageBytes);
      return true;
    }
    return _compareTolerant(imageBytes, golden);
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;

  File _fileFor(Uri golden) => File('${basePath.replaceAll('\\', '/')}/$golden');

  Future<bool> _compareTolerant(Uint8List imageBytes, Uri golden) async {
    final File file = _fileFor(golden);
    if (!file.existsSync()) {
      throw FlutterError('Golden file not found: ${file.path}');
    }

    final Uint8List? got = await _rgba(imageBytes);
    final Uint8List? want = await _rgba(await file.readAsBytes());
    if (got == null || want == null) return false;
    if (got.length != want.length) {
      throw FlutterError(
        'Golden ${file.path} has a different size than the rendered '
        'image, so the layout changed. This is a real failure.',
      );
    }

    int changed = 0;
    for (int i = 0; i < got.length; i++) {
      if ((got[i] - want[i]).abs() > channelTolerance) changed++;
    }
    if (changed > 0) {
      final int pixels = got.length ~/ 4;
      throw FlutterError(
        'Golden ${file.path} failed: $changed of $pixels pixels changed by '
        'more than $channelTolerance/255.',
      );
    }
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final File file = _fileFor(golden);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(imageBytes);
  }

  static Future<Uint8List?> _rgba(Uint8List bytes) async {
    final ui.Image image = await decodeImageFromList(bytes);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data?.buffer.asUint8List();
  }
}
