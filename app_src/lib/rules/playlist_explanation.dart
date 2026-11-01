library;

import '../l10n/app_localizations.dart';
import '../library/track.dart';
import 'context_rules.dart';
import 'rules_engine.dart';

class ExplanationLine {
  const ExplanationLine(this.text, {this.counts = true});

  final String text;

  final bool counts;
}

class PlaylistExplanation {
  const PlaylistExplanation({
    required this.context,
    required this.playing,
    required this.excluded,
    this.moment,
  });

  final List<ExplanationLine> context;

  final List<ExplanationLine> playing;

  final List<ExplanationLine> excluded;

  final String? moment;
}

String? momentSentence({
  required AppLocalizations l10n,
  String? placeName,
  bool preciseFix = true,
  bool betweenPlaces = false,
  bool commuting = false,
  bool raining = false,
  bool snowing = false,
  bool sleeping = false,
  bool manualMode = false,
  String? bandName,
}) {
  final parts = <String>[];

  if (placeName != null && placeName.trim().isNotEmpty) {
    parts.add(preciseFix ? l10n.explainAtPlace(placeName) : l10n.explainNearPlace(placeName));
  } else if (commuting) {
    parts.add(l10n.explainOnTheMove);
  } else if (betweenPlaces) {
    parts.add(l10n.explainBetweenPlaces);
  }

  if (snowing) {
    parts.add(l10n.explainSnowingOutside);
  } else if (raining) {
    parts.add(l10n.explainRainingOutside);
  }

  if (sleeping) {
    parts.add(l10n.explainEasierSleeping);
  }

  if (parts.isEmpty && bandName != null && bandName.isNotEmpty) {
    parts.add(l10n.explainItsBand(bandName));
  }
  if (parts.isEmpty && manualMode) {
    parts.add(l10n.explainSetByHand);
  }

  return parts.isEmpty ? null : parts.join(' ');
}

PlaylistExplanation explainPlaylist({
  required AppLocalizations l10n,
  required Track? current,
  required List<Track> library,
  required PlaylistContext? ctx,
  required RulesEngine engine,
  required FeedbackMemory memory,
  required String preferredOrigin,
  ContextRule? rule,
  int? ruleTrackCount,

  /// The band's word from the app's own words, not the enum's name.
  String? bandName,

  String? placeName,

  bool preciseFix = true,

  String? situationTag,

  bool sleeping = false,

  bool isLive = false,
}) {
  final context = <ExplanationLine>[];

  if (ctx == null) {
    context.add(ExplanationLine(l10n.explainNoReading, counts: false));
  }
  if (ctx != null) {
    if (sleeping) {
      context.add(ExplanationLine(l10n.explainSleepArmed));
    } else if (situationTag == 'snow') {
      context.add(ExplanationLine(l10n.explainSnowRule));
    } else if (situationTag == 'rain') {
      context.add(ExplanationLine(l10n.explainRainRule));
    } else if (ctx.commuting) {
      context.add(ExplanationLine(l10n.explainCommuteRules));
    } else if (placeName != null) {
      context.add(ExplanationLine(
        preciseFix ? l10n.explainHereAt(placeName) : l10n.explainHereApprox(placeName),
        counts: true,
      ));
    } else if (ctx.mode != null) {
      context.add(ExplanationLine(
        l10n.explainSetByHandNamed(ctx.mode!.name),
        counts: true,
      ));
    } else {
      context.add(ExplanationLine(
        l10n.explainHourPicked(bandName ?? ctx.band.name),
        counts: true,
      ));
    }

    if (rule != null) {
      context.add(ExplanationLine(
        'Rule "${rule.id}" matched: ${rule.describe()}.',
        counts: true,
      ));
      if (rule.playlist != null && ruleTrackCount != null) {
        context.add(ExplanationLine(
          ruleTrackCount < 3
              ? '"${rule.playlist}" holds $ruleTrackCount — those lead, the rest of the library follows.'
              : '"${rule.playlist}" became the queue ($ruleTrackCount tracks).',
          counts: true,
        ));
      }
    }
  }

  if (!isLive && ctx != null) {
    context.add(ExplanationLine(l10n.explainFixedQueue, counts: false));
  }

  final playing = <ExplanationLine>[];
  if (current == null) {
    playing.add(ExplanationLine(l10n.explainNothingPlaying));
  } else if (ctx != null && library.isNotEmpty) {
    final net = memory.score(current.id, ctx.band);
    if (net > 0) {
      playing.add(ExplanationLine(l10n.explainKeptIt(net)));
    }
  }

  final excluded = <ExplanationLine>[];

  return PlaylistExplanation(
    context: context,
    playing: playing,
    excluded: excluded,
    moment: momentSentence(
      l10n: l10n,
      placeName: placeName,
      preciseFix: preciseFix,
      betweenPlaces: ctx?.hasPlaceReading == true,
      commuting: ctx?.commuting ?? false,
      raining: ctx?.raining ?? false,
      snowing: ctx?.snowing ?? false,
      sleeping: sleeping,
      manualMode: ctx?.mode != null,
      bandName: bandName,
    ),
  );
}
