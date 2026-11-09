library;

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
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

  static const String _sep = '/';

  /// A path under the library root, or null when [relative] tries to climb out
  /// of it. The manifest is a document from elsewhere — a PC build script, a
  /// hand edit — so `../` in it must not become a read anywhere on the device.
  String? _underRoot(String relative) {
    final normalised = _relativeUnderRoot(relative);
    if (normalised == null) return null;
    return '$_libraryRoot$_sep$normalised';
  }

  static String? _relativeUnderRoot(String relative) {
    final out = <String>[];
    for (final segment in relative.replaceAll(r'\', _sep).split(_sep)) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (out.isEmpty) return null;
        out.removeLast();
        continue;
      }
      out.add(segment);
    }
    return out.isEmpty ? null : out.join(_sep);
  }

  /// The root-relative name of the manifest, which this class chose itself.
  String get _manifestPath => '$_libraryRoot$_sep$kManifestFileName';

  /// Set before [load] when the folder lives somewhere other than the default.
  String? _root;

  set root(String? value) => _root = value;

  Future<String> _resolveRoot() async => _root ?? kAndroidLibraryRoot;

  Future<void> load() async {
    _accessDenied = false;
    _libraryRoot = await _resolveRoot();
    _scan = await LibraryScan.of(_libraryRoot!);

    final external = File(_manifestPath);
    try {
      if (await external.exists()) {
        // A manifest that is truncated or wrong-typed is an empty library with
        // a line in the log, not a boot that never finishes.
        List<Track> parsed;
        try {
          parsed = Track.listFromManifest(await external.readAsString());
        } catch (e) {
          debugPrint('[Sonarar][LIB] manifest unreadable: $e');
          parsed = const [];
        }
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
    } catch (e) {
      // The demo library is a convenience; a build without it is not an error.
      debugPrint('[Sonarar][LIB] bundled manifest failed: $e');
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

  /// Where the file actually is, asked of the disk before the manifest: a moved or
  /// renamed file still plays, and one the scan cannot find is reported missing
  /// rather than handed to the player to fail on. With no walk to ask, the manifest
  /// answers alone.
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
