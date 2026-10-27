library;

import 'dart:convert';
import 'dart:io';

import 'play_log.dart';

class BondConfig {
  const BondConfig({
    this.completionPoints = 6,
    this.earlySkipPenalty = 3,
    this.resetAt,
  });

  final int completionPoints;

  final int earlySkipPenalty;

  final DateTime? resetAt;

  BondConfig withResetAt(DateTime? at) => BondConfig(
        completionPoints: completionPoints,
        earlySkipPenalty: earlySkipPenalty,
        resetAt: at,
      );

  Map<String, Object?> toJson() => {
        'completion_points': completionPoints,
        'early_skip_penalty': earlySkipPenalty,
        'reset_at': resetAt?.toIso8601String(),
      };

  static BondConfig fromJson(Object? raw) {
    if (raw is! Map) return const BondConfig();
    final reset = raw['reset_at'];
    return BondConfig(
      completionPoints:
          (raw['completion_points'] as num?)?.toInt() ?? 6,
      earlySkipPenalty: (raw['early_skip_penalty'] as num?)?.toInt() ?? 3,
      resetAt: reset is String ? DateTime.tryParse(reset) : null,
    );
  }
}

class Bond {
  const Bond({
    required this.trackId,
    required this.points,
    required this.completions,
    required this.earlySkips,
    required this.contexts,
  });

  final String trackId;

  final int points;

  final int completions;
  final int earlySkips;

  final int contexts;

  int get rank {
    var r = 0;
    for (final threshold in kBondLadder) {
      if (points >= threshold) r++;
    }
    return r - 1 < 0 ? 0 : r - 1;
  }

  BondRankInfo get rankInfo => kBondRanks[rank];
}

const List<int> kBondLadder = [0, 10, 25, 50, 90, 140];

class BondRankInfo {
  const BondRankInfo({required this.name, required this.unlocks});

  final String name;

  final String unlocks;
}

const List<BondRankInfo> kBondRanks = [
  BondRankInfo(name: 'Stranger', unlocks: 'Nothing yet — play it a few times.'),
  BondRankInfo(name: 'Acquaintance', unlocks: 'Nothing yet.'),
  BondRankInfo(name: 'Contact', unlocks: 'Nothing yet.'),
  BondRankInfo(name: 'Confidant', unlocks: 'You can write a note on this bond.'),
  BondRankInfo(name: 'Ally', unlocks: 'You can write a note on this bond.'),
  BondRankInfo(name: 'Partner', unlocks: 'You can write a note on this bond.'),
];

class BondState {
  BondState({BondConfig? config, Map<String, String>? notes})
      : config = config ?? const BondConfig(),
        _notes = {...?notes};

  BondConfig config;
  final Map<String, String> _notes;

  Map<String, String> get notes => Map.unmodifiable(_notes);

  String? noteFor(String trackId) => _notes[trackId];

  bool setNote(String trackId, String text, {required int rank}) {
    if (rank < kNoteRank) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _notes.remove(trackId);
      return true;
    }
    _notes[trackId] = trimmed;
    return true;
  }

  static const int kNoteRank = 3;

  void prune(Set<String> libraryIds) =>
      _notes.removeWhere((id, _) => !libraryIds.contains(id));

  Map<String, Object?> toJson() => {
        'config': config.toJson(),
        'notes': _notes,
      };

  static BondState decode(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is! Map) return BondState();
      final notes = raw['notes'];
      return BondState(
        config: BondConfig.fromJson(raw['config']),
        notes: notes is Map
            ? {
                for (final e in notes.entries)
                  if (e.key is String && e.value is String && e.key.isNotEmpty)
                    e.key as String: (e.value as String).trim(),
              }
            : null,
      );
    } on FormatException {
      return BondState();
    }
  }
}

class BondStore {
  BondStore(this.file);

  final File file;

  Future<BondState> load() async {
    if (!file.existsSync()) return BondState();
    try {
      return BondState.decode(await file.readAsString());
    } on FileSystemException {
      return BondState();
    }
  }

  Future<void> save(BondState state) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(state.toJson()));
  }
}

class BondBoard {
  const BondBoard({
    required this.bonds,
    required this.config,
    required this.consideredEvents,
  });

  final List<Bond> bonds;

  final BondConfig config;

  final int consideredEvents;

  bool get isEmpty => bonds.isEmpty;

  Bond? forTrack(String trackId) {
    for (final b in bonds) {
      if (b.trackId == trackId) return b;
    }
    return null;
  }
}

BondBoard buildBonds(
  List<PlayEvent> events, {
  BondState? state,
  int limit = 50,
}) {
  final config = state?.config ?? const BondConfig();
  final reset = config.resetAt;

  final points = <String, int>{};
  final completions = <String, int>{};
  final skips = <String, int>{};
  final bands = <String, Set<String>>{};

  final doneInBand = <String, int>{};
  final skippedInBand = <String, int>{};

  var considered = 0;

  for (final e in events) {
    if (reset != null && e.at.isBefore(reset)) continue;

    final counted = isCountedPlay(e);

    final earlySkip = !e.completed && e.positionMs < kMinPlayMs;
    if (!counted && !earlySkip) continue;

    considered++;
    bands.putIfAbsent(e.trackId, () => <String>{}).add(e.band);

    if (earlySkip) {
      final k = '${e.trackId}@${e.band}';
      final n = (skippedInBand[k] ?? 0) + 1;
      skippedInBand[k] = n;
      skips[e.trackId] = (skips[e.trackId] ?? 0) + 1;
      points[e.trackId] =
          (points[e.trackId] ?? 0) - (config.earlySkipPenalty / n).round();
      continue;
    }

    completions[e.trackId] = (completions[e.trackId] ?? 0) + 1;
    if (e.completed) {
      final k = '${e.trackId}@${e.band}';
      final n = (doneInBand[k] ?? 0) + 1;
      doneInBand[k] = n;
      points[e.trackId] =
          (points[e.trackId] ?? 0) + (config.completionPoints / n).round();
    }
  }

  final out = <Bond>[];
  for (final id in bands.keys) {
    out.add(Bond(
      trackId: id,
      points: points[id] ?? 0,
      completions: completions[id] ?? 0,
      earlySkips: skips[id] ?? 0,
      contexts: bands[id]!.length,
    ));
  }

  out.sort((a, b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    final byCompletions = b.completions.compareTo(a.completions);
    if (byCompletions != 0) return byCompletions;
    return a.trackId.compareTo(b.trackId);
  });

  return BondBoard(
    bonds: out.take(limit).toList(growable: false),
    config: config,
    consideredEvents: considered,
  );
}
