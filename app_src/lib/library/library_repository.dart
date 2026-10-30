library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../core/constants.dart';
import 'library_scan.dart';
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

  /// What the disk held the last time we looked. Null until [load] has run.
  LibraryScan? _scan;
  LibraryScan? get scan => _scan;

  Set<String> _missingIds = const {};
  Set<String> get missingIds => _missingIds;

  /// Only a manifest that came off the disk can disagree with the disk. The
  /// bundled demo library ships inside the APK; nothing is expected of it.
  /// (A flag, not a path prefix: Windows roots do not start with a slash.)
  bool _fromDisk = false;
  bool get _canCheckDisk => _fromDisk;

  bool get isEmpty => _tracks.isEmpty;

  String get _sep => '/';

  String _underRoot(String relative) {
    final normalised = relative.replaceAll('/', _sep).replaceAll(r'\', _sep);
    return '$_libraryRoot$_sep$normalised';
  }

  /// Set before [load] when the folder lives somewhere other than the default.
  String? _root;

  set root(String? value) => _root = value;

  Future<String> _resolveRoot() async => _root ?? kAndroidLibraryRoot;

  Future<void> load() async {
    _accessDenied = false;
    _libraryRoot = await _resolveRoot();
    _scan = await LibraryScan.of(_libraryRoot!);

    final external = File(_underRoot(kManifestFileName));
    try {
      if (await external.exists()) {
        final parsed = Track.listFromManifest(await external.readAsString());
        if (parsed.isNotEmpty) {
          _tracks = parsed;
          _loadedFrom = external.path;
          _fromDisk = true;
          _recomputeMissing();
          return;
        }
      }
    } on FileSystemException {
      _accessDenied = true;
    }

    if (!await _canReadRoot()) {
      _accessDenied = true;
    }

    // A chosen folder that has lost its manifest must read as empty, not as the
    // demo library shipped in the APK — that would look like the music vanished.
    if (_root != null) {
      _tracks = const [];
      _loadedFrom = null;
      _fromDisk = false;
      _missingIds = const {};
      return;
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

  /// Where the file actually is, asked of the disk before the manifest.
  ///
  /// The scan answers when it can — a moved or renamed file still plays, and a
  /// file it cannot find is reported missing instead of being handed to the
  /// player to fail on. When the walk failed (no permission, no such folder)
  /// this behaves exactly as it did before there was a scan.
  String? absoluteFor(Track track) {
    if (_libraryRoot == null) return null;
    final resolved = _scan?.resolve(track.file);
    if (resolved != null) return resolved;
    return _underRoot(track.file);
  }

  void _recomputeMissing() {
    if (!_canCheckDisk) {
      _missingIds = const {};
      return;
    }
    final scan = _scan;
    if (scan == null || !scan.isReadable) {
      _missingIds = const {};
      return;
    }
    _missingIds = {
      for (final track in _tracks)
        if (scan.resolveRelative(track.file) == null) track.id,
    };
  }

  /// Re-walks the disk without re-reading the manifest.
  ///
  /// Returns true when the answer changed, so a caller can decide whether the
  /// library it already handed to the UI is stale.
  Future<bool> refresh() async {
    final root = _libraryRoot;
    if (root == null || _tracks.isEmpty) return false;
    final before = _missingIds;
    _scan = await LibraryScan.of(root);
    _recomputeMissing();
    return !_sameSet(before, _missingIds);
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  String? coverPathFor(Track track) {
    if (_libraryRoot == null || track.cover.isEmpty) return null;
    return _underRoot(track.cover);
  }
}
