library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../core/constants.dart';
import 'track.dart';

class LibraryRepository {
  LibraryRepository();

  List<Track> _tracks = const [];
  List<Track> get tracks => _tracks;

  String? _libraryRoot;
  String? get libraryRoot => _libraryRoot;

  bool _accessDenied = false;
  bool get accessDenied => _accessDenied;

  String? _loadedFrom;
  String? get loadedFrom => _loadedFrom;

  bool get isEmpty => _tracks.isEmpty;

  String get _sep => '/';

  String _underRoot(String relative) {
    final normalised = relative.replaceAll('/', _sep).replaceAll(r'\', _sep);
    return '$_libraryRoot$_sep$normalised';
  }

  Future<String> _resolveRoot() async => kAndroidLibraryRoot;

  Future<void> load() async {
    _libraryRoot = await _resolveRoot();

    final external = File(_underRoot(kManifestFileName));
    try {
      if (await external.exists()) {
        final parsed = Track.listFromManifest(await external.readAsString());
        if (parsed.isNotEmpty) {
          _tracks = parsed;
          _loadedFrom = external.path;
          return;
        }
      }
    } on FileSystemException {
      _accessDenied = true;
    }

    if (!await _canReadRoot()) {
      _accessDenied = true;
    }

    try {
      final bundled = await rootBundle.loadString(kBundledManifest);
      final parsed = Track.listFromManifest(bundled);
      if (parsed.isNotEmpty) {
        _tracks = parsed;

        _loadedFrom = 'bundled:$kBundledManifest';
        return;
      }
    } catch (_) {
    }

    _tracks = const [];
    _loadedFrom = null;
  }

  Future<bool> _canReadRoot() async {
    final root = _libraryRoot;
    if (root == null) return true;
    try {
      final dir = Directory(root);
      if (!await dir.exists()) return true;
      await dir.list().take(1).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  String? absoluteFor(Track track) {
    if (_libraryRoot == null) return null;
    return _underRoot(track.file);
  }

  String? coverPathFor(Track track) {
    if (_libraryRoot == null || track.cover.isEmpty) return null;
    return _underRoot(track.cover);
  }
}
