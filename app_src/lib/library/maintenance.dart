library;

import 'track.dart';

const Duration kSuspiciouslyShort = Duration(seconds: 30);

class CleanupFinding {
  const CleanupFinding({
    required this.kind,
    required this.trackIds,
    required this.detail,
  });

  final CleanupKind kind;
  final List<String> trackIds;

  final String detail;

  int get count => trackIds.length;
}

enum CleanupKind {
  veryShort,

  noDuration,

  missingMetadata,

  noCover,

  sameFile,
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.key,
    required this.tracks,
    required this.reason,
  });

  final String key;
  final List<Track> tracks;
  final String reason;
}

const String _kVersionWords =
    'ver|version|remaster|remastered|remix|live|reload|reincarnation|'
    'instrumental|off vocal|offvocal|tv size|tvsize|short|'
    'p3r|p4r|p5r|p3|p4|p5';

final RegExp _bracketedSuffix =
    RegExp('\\([^)]*\\b(?:$_kVersionWords)\\b[^)]*\\)\$|\\[[^\\]]*\\b(?:$_kVersionWords)\\b[^\\]]*\\]\$');

final RegExp _dashSuffix =
    RegExp('\\s*[-–—]\\s*(?:$_kVersionWords)\\s*[-–—]?\\s*\$');

String normaliseTitle(String title) {
  var t = title.trim().toLowerCase();
  var before = '';
  while (before != t) {
    before = t;
    t = t.replaceFirst(_bracketedSuffix, '').trim();
    t = t.replaceFirst(_dashSuffix, '').trim();

    t = t.replaceFirst(
      RegExp('\\s+\\b(?:$_kVersionWords)\\b\\.?\$'),
      '',
    ).trim();
  }

  t = t.replaceAll(RegExp(r'[^\w\s]'), ' ');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

List<DuplicateGroup> findDuplicates(List<Track> tracks) {
  final byKey = <String, List<Track>>{};
  for (final t in tracks) {
    final title = normaliseTitle(t.title);
    if (title.isEmpty) continue;
    byKey.putIfAbsent(
      '$title@@${t.artist.trim().toLowerCase()}',
      () => <Track>[],
    ).add(t);
  }

  final out = <DuplicateGroup>[];
  byKey.forEach((key, group) {
    if (group.length < 2) return;
    final title = key.split('@@').first;
    out.add(DuplicateGroup(
      key: title,
      tracks: group,
      reason: '${group.length} tracks share the title "$title" and the same '
          'artist, once version suffixes are ignored.',
    ));
  });
  out.sort((a, b) => a.key.compareTo(b.key));
  return out;
}

List<CleanupFinding> reviewLibrary(List<Track> tracks) {
  final short = <String>[];
  final noDuration = <String>[];
  final missing = <String>[];
  final noCover = <String>[];
  final byFile = <String, List<String>>{};

  for (final t in tracks) {
    if (t.duration <= Duration.zero) {
      noDuration.add(t.id);
    } else if (t.duration < kSuspiciouslyShort) {
      short.add(t.id);
    }

    final title = t.title.trim().toLowerCase();
    final artist = t.artist.trim().toLowerCase();
    if (title.isEmpty ||
        artist.isEmpty ||
        title == 'untitled' ||
        artist == 'unknown artist') {
      missing.add(t.id);
    }

    if (t.cover.trim().isEmpty) noCover.add(t.id);

    byFile.putIfAbsent(t.file, () => <String>[]).add(t.id);
  }

  final sameFile = <String>[];
  byFile.forEach((file, ids) {
    if (ids.length > 1) sameFile.addAll(ids);
  });

  final out = <CleanupFinding>[];
  if (noDuration.isNotEmpty) {
    out.add(CleanupFinding(
      kind: CleanupKind.noDuration,
      trackIds: noDuration,
      detail: '${noDuration.length} track'
          '${noDuration.length == 1 ? " has" : "s have"} no readable duration — '
          'the tag could not be read at build time.',
    ));
  }
  if (short.isNotEmpty) {
    out.add(CleanupFinding(
      kind: CleanupKind.veryShort,
      trackIds: short,
      detail: '${short.length} track'
          '${short.length == 1 ? " is" : "s are"} under '
          '${kSuspiciouslyShort.inSeconds}s — jingle-length. Worth a listen, '
          'not an action.',
    ));
  }
  if (missing.isNotEmpty) {
    out.add(CleanupFinding(
      kind: CleanupKind.missingMetadata,
      trackIds: missing,
      detail: '${missing.length} track'
          '${missing.length == 1 ? " has" : "s have"} a blank or placeholder '
          'title or artist. Fixable in TAGS.',
    ));
  }
  if (sameFile.isNotEmpty) {
    out.add(CleanupFinding(
      kind: CleanupKind.sameFile,
      trackIds: sameFile,
      detail: '${sameFile.length} tracks point at the same audio file — the '
          'same recording indexed more than once.',
    ));
  }
  if (noCover.isNotEmpty) {
    out.add(CleanupFinding(
      kind: CleanupKind.noCover,
      trackIds: noCover,
      detail: '${noCover.length} track'
          '${noCover.length == 1 ? " has" : "s have"} no cover art. Cosmetic '
          'only — the theme art is drawn instead.',
    ));
  }
  return out;
}
