library;

import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel kSpectrumChannel =
    MethodChannel('com.noah.personar/spectrum');

class SpectrumBuilder {
  SpectrumBuilder({
    required this.libraryRoot,
    MethodChannel? channel,
  }) : _channel = channel ?? kSpectrumChannel;

  final String? libraryRoot;

  final MethodChannel _channel;

  final _attempted = <String>{};

  bool get busy => _inFlight;
  bool _inFlight = false;

  Future<bool> ensure({
    required String trackId,
    required String audioPath,
  }) async {
    final root = libraryRoot;
    if (root == null || trackId.isEmpty) return false;

    final file = File('$root${Platform.pathSeparator}spectrum'
        '${Platform.pathSeparator}$trackId.bin');

    if (file.existsSync()) return false;

    if (!_attempted.add(trackId)) return false;

    _inFlight = true;
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'build',
        {'path': audioPath},
      );
      if (bytes == null || bytes.isEmpty) return false;

      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on FileSystemException {
      return false;
    } finally {
      _inFlight = false;
    }
  }
}
