library;

import 'dart:io';

/// What is actually on the disk under the library root, kept as a cache.
///
/// The manifest names files; the disk decides whether they are there. Trusting
/// the manifest alone means a renamed or moved file stays in the library as a
/// row that plays nothing, and a file dropped in by a downloader does not exist
/// until something rewrites the manifest.
///
/// So: walk the root once, keep the result, and let callers ask *this* where a
/// track really is. The cache is cheap to rebuild — names and sizes, no tags,
/// no hashing — and it is thrown away rather than patched, so it cannot drift.
///
/// Modelled on Mihon's `DownloadCache`: the filesystem is the authority, and
/// stored links are hints to be resolved, not truths to be trusted.
class LibraryScan {
  LibraryScan._(this.root, this._files, this._byName, this.scannedAt);

  /// Indexes by basename on the way in, because a rename is the one mismatch
  /// worth resolving and doing it lazily would put the walk's cost on the
  /// first missing track instead of on the walk.
  factory LibraryScan.files(
    String root,
    Map<String, int> files,
    DateTime scannedAt,
  ) {
    final byName = <String, List<String>>{};
    for (final path in files.keys) {
      (byName[_basename(path)] ??= <String>[]).add(path);
    }
    return LibraryScan._(root, files, byName, scannedAt);
  }

  /// An empty scan for a root that could not be read. Resolution falls back to
  /// the stored path, which is what every build before this one did anyway.
  const LibraryScan.unreadable(this.root)
      : _files = const {},
        _byName = const {},
        scannedAt = null;

  final String root;
  final DateTime? scannedAt;

  /// Relative path (always `/`-separated, no leading slash) to byte size.
  final Map<String, int> _files;
  final Map<String, List<String>> _byName;

  static const Set<String> audioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.ogg',
    '.opus',
    '.wav',
    '.wv',
    '.aiff',
    '.aif',
    '.wma',
  };

  /// How long a scan is worth believing. Long enough that opening the app is
  /// not a directory walk, short enough that moving files around is noticed
  /// without a restart.
  static const Duration maxAge = Duration(hours: 1);

  bool get isReadable => scannedAt != null;

  int get fileCount => _files.length;

  bool get hasAudio => _files.keys.any(isAudio);

  /// Files that look like music. The manifest is still what makes a track; this
  /// is only for noticing what the manifest has not been told about.
  List<String> get audioFiles =>
      _files.keys.where(isAudio).toList(growable: false);

  static bool isAudio(String relative) {
    final dot = relative.lastIndexOf('.');
    if (dot < 0) return false;
    return audioExtensions.contains(relative.substring(dot).toLowerCase());
  }

  /// Walks [root]. Never throws: an unreadable or missing root comes back as
  /// [LibraryScan.unreadable], and callers fall back to the stored paths.
  ///
  /// Symlinks are not followed — a link loop would turn a library walk into a
  /// hang, and the files a link points at are reachable at their real path.
  static Future<LibraryScan> of(String root, {DateTime? now}) async {
    final files = <String, int>{};
    try {
      final dir = Directory(root);
      if (!await dir.exists()) return const LibraryScan.unreadable('');
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = _relativeTo(root, entity.path);
        if (relative.isEmpty) continue;
        try {
          files[relative] = await entity.length();
        } on FileSystemException {
          // Vanished between the listing and the stat. Not our problem.
        }
      }
    } on FileSystemException {
      return const LibraryScan.unreadable('');
    }
    return LibraryScan.files(root, files, now ?? DateTime.now());
  }

  bool isStale(DateTime now) {
    final at = scannedAt;
    if (at == null) return true;
    return now.difference(at) > maxAge;
  }

  /// True when the file the manifest names is still at the path it names.
  bool holds(String relative) => _files.containsKey(_normalise(relative));

  /// Where a track's file is *now*, or null when it is nowhere.
  ///
  /// Exact path first — the common case, and the only one where we know for
  /// certain. Then a rename: same filename, one place in the tree. A name that
  /// appears twice is not guessed at, because the wrong file is worse than a
  /// missing one.
  String? resolve(String relative) {
    if (!isReadable) return null;
    final wanted = _normalise(relative);
    if (_files.containsKey(wanted)) return _absolute(wanted);
    final candidates = _byName[_basename(wanted)];
    if (candidates == null || candidates.length != 1) return null;
    return _absolute(candidates.single);
  }

  /// The relative path a track's file resolved to, for callers that want to
  /// know it moved rather than just play it.
  String? resolveRelative(String relative) {
    if (!isReadable) return null;
    final wanted = _normalise(relative);
    if (_files.containsKey(wanted)) return wanted;
    final candidates = _byName[_basename(wanted)];
    if (candidates == null || candidates.length != 1) return null;
    return candidates.single;
  }

  String _absolute(String relative) => '$root/$relative';

  static String _normalise(String path) {
    var p = path.replaceAll(r'\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  static String _basename(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  static String _relativeTo(String root, String path) {
    var base = root.replaceAll(r'\', '/');
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var p = path.replaceAll(r'\', '/');
    if (p.startsWith('$base/')) p = p.substring(base.length + 1);
    return _normalise(p);
  }
}
