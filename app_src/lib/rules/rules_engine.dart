library;

import '../library/track.dart';
import '../theme/skin.dart';
import '../theme/skin_policy.dart';

const String kWhimsicalAlbum = 'Weathering With You';

enum Energy { low, medium, high }

class PlaylistContext {
  const PlaylistContext({
    required this.band,
    required this.localHour,
    this.mode,
    this.placeId,
    this.sky = Sky.unknown,
    this.whereabouts = Whereabouts.unknown,
  });

  final ContextBand band;

  final Sky sky;
  final Whereabouts whereabouts;

  final int localHour;

  bool get raining => sky == Sky.rain || sky == Sky.drizzle || sky == Sky.thunder;
  bool get snowing => sky == Sky.snow;
  bool get atHome => whereabouts == Whereabouts.home;
  bool get commuting => whereabouts == Whereabouts.commuting;
  bool get hasPlaceReading => whereabouts != Whereabouts.unknown;

  final ManualMode? mode;

  final String? placeId;

  PlaylistContext copyWith({
    ContextBand? band,
    int? localHour,
    ManualMode? mode,
    String? placeId,
    Sky? sky,
    Whereabouts? whereabouts,
    bool clearMode = false,
    bool clearPlace = false,
  }) =>
      PlaylistContext(
        band: band ?? this.band,
        localHour: localHour ?? this.localHour,
        mode: clearMode ? null : (mode ?? this.mode),

        placeId: clearPlace ? null : (placeId ?? this.placeId),
        sky: sky ?? this.sky,
        whereabouts: whereabouts ?? this.whereabouts,
      );

  Energy get energy => switch (band) {
        ContextBand.darkHour => Energy.low,
        ContextBand.night => Energy.low,
        ContextBand.morning => Energy.medium,
        ContextBand.afternoon => Energy.high,
        ContextBand.evening => Energy.medium,
      };

  Energy get effectiveEnergy =>
      mode == ManualMode.battle ? Energy.high : energy;
}

enum SkipFeedback { none, rejected, accepted }

class LearnedEntry {
  const LearnedEntry({
    required this.trackId,
    required this.band,
    required this.acceptances,
    required this.rejections,
  });

  final String trackId;
  final ContextBand band;
  final int acceptances;
  final int rejections;

  int get score => acceptances - rejections;

  bool get suppressed => -score >= FeedbackMemory.suppressThreshold;

  bool get isEmpty => acceptances == 0 && rejections == 0;
}

class FeedbackMemory {
  final Map<String, int> _rejections = {};
  final Map<String, int> _acceptances = {};

  String _key(String trackId, ContextBand band) => '$trackId@${band.name}';

  void record(String trackId, ContextBand band, SkipFeedback feedback) {
    if (feedback != SkipFeedback.accepted) return;
    final k = _key(trackId, band);
    _acceptances[k] = (_acceptances[k] ?? 0) + 1;
  }

  int rejections(String trackId, ContextBand band) =>
      _rejections[_key(trackId, band)] ?? 0;

  int acceptances(String trackId, ContextBand band) =>
      _acceptances[_key(trackId, band)] ?? 0;

  int score(String trackId, ContextBand band) => acceptances(trackId, band);

  static const int suppressThreshold = 2;

  bool isSuppressed(String trackId, ContextBand band) => false;

  void forget(String trackId, ContextBand band) {
    final k = _key(trackId, band);
    _rejections.remove(k);
    _acceptances.remove(k);
  }

  List<LearnedEntry> get learned {
    final out = <LearnedEntry>[];
    final keys = {..._rejections.keys, ..._acceptances.keys};
    for (final k in keys) {
      final at = k.lastIndexOf('@');
      if (at <= 0) continue;
      final trackId = k.substring(0, at);
      final bandName = k.substring(at + 1);
      final band = ContextBand.values
          .where((b) => b.name == bandName)
          .firstOrNull;
      if (band == null) continue;
      out.add(LearnedEntry(
        trackId: trackId,
        band: band,
        acceptances: _acceptances[k] ?? 0,
        rejections: _rejections[k] ?? 0,
      ));
    }
    out.sort((a, b) => a.score.compareTo(b.score));
    return out;
  }

  void clear() {
    _rejections.clear();
    _acceptances.clear();
  }

  int get size => _rejections.length + _acceptances.length;
}

class RulesEngine {
  const RulesEngine();

  String originOf(Track t) {
    final hay = '${t.album} ${t.artist}'.toLowerCase();
    if (hay.contains('p5') || hay.contains('persona 5')) return 'P5R';
    if (hay.contains('p4') || hay.contains('persona 4')) return 'P4R';
    if (hay.contains('p3') || hay.contains('persona 3')) return 'P3R';
    return 'other';
  }

  bool admits(
    Track t,
    PlaylistContext ctx, {
    Set<String> excluded = const {},
  }) => !excluded.contains(t.id);

  List<Track> select(
    List<Track> library,
    PlaylistContext ctx, {
    Set<String> excluded = const {},
  }) =>
      library
          .where((t) => admits(t, ctx, excluded: excluded))
          .toList(growable: false);

  List<Track> playlist(
    List<Track> library,
    PlaylistContext ctx, {
    Set<String> excluded = const {},
  }) {
    return select(library, ctx, excluded: excluded);
  }

  LibraryFit fitFor(List<Track> library, SkinId skin) {
    final want = switch (skin) {
      SkinId.amber => 'P4R',
      SkinId.crimson => 'P5R',
      SkinId.abyss => 'P3R',
      SkinId.minimal || SkinId.mono || SkinId.bloom => null,
    };
    if (want == null) {
      return LibraryFit(skin: skin, wanted: null, matching: 0, total: library.length);
    }
    final have = library.where((t) => originOf(t) == want).length;
    return LibraryFit(
      skin: skin,
      wanted: want,
      matching: have,
      total: library.length,
    );
  }
}

class LibraryFit {
  const LibraryFit({
    required this.skin,
    required this.wanted,
    required this.matching,
    required this.total,
  });

  final SkinId skin;

  final String? wanted;
  final int matching;
  final int total;

  static const double thinThreshold = 0.25;

  bool get isThin => total == 0 || matching / total < thinThreshold;

  String get summary {
    if (matching == 0) {
      return 'No $wanted music in the library — this theme plays the P3R tracks.';
    }
    if (isThin) {
      return 'Only $matching of $total tracks are $wanted — this theme mostly '
          'plays the P3R tracks.';
    }
    return '$matching of $total tracks are $wanted.';
  }
}
