library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;

import 'personalization.dart';

/// Where the phone keeps pictures the user already has.
///
/// No file-picker dependency: the app already holds all-files access to write
/// into the music folder, so it can read the standard picture folders directly.
/// Fewer moving parts and no second permission prompt.
List<Directory> pictureFolders() {
  if (!Platform.isAndroid) return const [];
  const roots = [
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/DCIM/Camera',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
  ];
  return [for (final r in roots) if (Directory(r).existsSync()) Directory(r)];
}

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

/// Newest first, because the picture someone wants is usually the last one they
/// took or saved.
List<File> candidateImages({int limit = 60}) {
  final found = <File>[];
  for (final dir in pictureFolders()) {
    try {
      for (final e in dir.listSync(followLinks: false)) {
        if (e is! File) continue;
        final name = e.path.toLowerCase();
        if (!_imageExtensions.any(name.endsWith)) continue;
        if (name.contains('/.')) continue;
        found.add(e);
      }
    } on FileSystemException {
      continue;
    }
  }
  found.sort((a, b) {
    try {
      return b.lastModifiedSync().compareTo(a.lastModifiedSync());
    } on FileSystemException {
      return 0;
    }
  });
  return found.take(limit).toList(growable: false);
}

/// Copy a chosen picture into the library, so the theme survives the original
/// being deleted from the gallery.
Future<File?> importBackground(Directory root, File source) async {
  try {
    final dir = Directory('${root.path}${Platform.pathSeparator}backgrounds');
    await dir.create(recursive: true);
    final ext = source.path.contains('.') ? source.path.substring(source.path.lastIndexOf('.')) : '.jpg';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dest = File('${dir.path}${Platform.pathSeparator}backdrop-$stamp$ext');
    await source.copy(dest.path);
    return dest;
  } on FileSystemException {
    return null;
  }
}

/// The accent a photo suggests, decoded small — 24px wide is enough to find the
/// dominant saturated colour and cheap enough to run on the tap.
Future<Color?> accentFromImage(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    frame.image.dispose();
    codec.dispose();
    if (data == null) return null;
    final pixels = Uint8List.sublistView(data);
    // A washed-out photo still has a colour in it; only give up when nothing
    // survives even a very low saturation floor.
    for (final floor in const [0.18, 0.10, 0.04]) {
      final colour = pickAccentFromPixels(pixels, minSat: floor);
      if (colour != null) return colour;
    }
    return null;
  } catch (_) {
    return null;
  }
}
