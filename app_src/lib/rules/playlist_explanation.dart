library;

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
    parts.add(preciseFix ? 'You are at $placeName.' : 'You are somewhere near $placeName.');
  } else if (commuting) {
    parts.add('You are on the move.');
  } else if (betweenPlaces) {
    parts.add('You are between your saved places.');
  }

  if (snowing) {
    parts.add("It's snowing outside.");
  } else if (raining) {
    parts.add("It's raining outside.");
  }

  if (sleeping) {
    parts.add('And you wanna have easier time when sleeping.');
  }

  if (parts.isEmpty && bandName != null && bandName.isNotEmpty) {
    parts.add("It's $bandName.");
  }
  if (parts.isEmpty && manualMode) {
    parts.add('You set this moment by hand.');
  }

  return parts.isEmpty ? null : parts.join(' ');
}

PlaylistExplanation explainPlaylist({
  required Track? current,
  required List<Track> library,
  required PlaylistContext? ctx,
  required RulesEngine engine,
  required FeedbackMemory memory,
  required String preferredOrigin,
  ContextRule? rule,
  int? ruleTrackCount,

  String? placeName,

  bool preciseFix = true,

  String? situationTag,

  bool sleeping = false,

  bool isLive = false,
}) {
  final context = <ExplanationLine>[];

  if (ctx == null) {
    context.add(const ExplanationLine(
      'Waiting for a context reading — nothing has decided anything yet.',
      counts: false,
    ));
  }
  if (ctx != null) {
    if (sleeping) {
      context.add(const ExplanationLine(
        'Sleep timer armed — instrumentals until it stops.',
        counts: true,
      ));
    } else if (situationTag == 'snow') {
      context.add(const ExplanationLine('Snowing — the snow rule is active.', counts: true));
    } else if (situationTag == 'rain') {
      context.add(const ExplanationLine('Raining — the rain rule is active.', counts: true));
    } else if (ctx.commuting) {
      context.add(const ExplanationLine('Travelling — the commute rules are active.', counts: true));
    } else if (placeName != null) {
      context.add(ExplanationLine(
        preciseFix ? 'At $placeName.' : 'At $placeName (approximate fix).',
        counts: true,
      ));
    } else if (ctx.mode != null) {
      context.add(ExplanationLine(
        'You set this context by hand (${ctx.mode!.name}).',
        counts: true,
      ));
    } else {
      context.add(ExplanationLine(
        '${ctx.band.name[0].toUpperCase()}${ctx.band.name.substring(1)} — the hour picked this.',
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
    context.add(const ExplanationLine(
      'Fixed queue — it plays in this order. Press Dynamic to let the app re-rank as things change.',
      counts: false,
    ));
  }

  final playing = <ExplanationLine>[];
  if (current == null) {
    playing.add(const ExplanationLine('Nothing is playing.'));
  } else if (ctx != null && library.isNotEmpty) {
    final net = memory.score(current.id, ctx.band);
    if (net > 0) {
      playing.add(ExplanationLine(
        'You kept it $net time${net == 1 ? '' : 's'} in this band.',
      ));
    }
  }

  final excluded = <ExplanationLine>[];

  return PlaylistExplanation(
    context: context,
    playing: playing,
    excluded: excluded,
    moment: momentSentence(
      placeName: placeName,
      preciseFix: preciseFix,
      betweenPlaces: ctx?.hasPlaceReading == true,
      commuting: ctx?.commuting ?? false,
      raining: ctx?.raining ?? false,
      snowing: ctx?.snowing ?? false,
      sleeping: sleeping,
      manualMode: ctx?.mode != null,
      bandName: ctx?.band.name,
    ),
  );
}
