library;

import '../rules/context_rules.dart';
import '../rules/rules_engine.dart' show PlaylistContext;
import '../theme/skin_policy.dart';
import 'playlists.dart';
import 'track.dart';

import 'dynamic_playlist.dart';

const int kDynamicMixLimit = 60;

typedef MixInputs = ({
  PlaylistContext context,

  List<Track> library,

  List<Playlist> playlists,

  List<String> situationIds,

  String? bandListName,

  ContextRules rules,

  bool contextEnabled,

  bool honourClock,

  bool sleeping,
});

class DynamicMixResolver {
  const DynamicMixResolver();

  Playlist? resolve(MixInputs input) {
    final ctx = input.context;
    if (input.library.isEmpty) return null;

    final leads = <String>[];
    void lead(List<String> ids) {
      for (final id in ids) {
        if (!leads.contains(id)) leads.add(id);
      }
    }

    if (input.contextEnabled) {
      lead(input.situationIds);
      if (ctx.raining || ctx.snowing) {
        lead(_byId(input.playlists, 'weathering'));
      }
    }

    if (input.contextEnabled && ctx.placeId != null) {
      lead(_byRef(input.playlists, ctx.placeId!));
    }

    if (input.contextEnabled && input.honourClock) {
      final band = ctx.band;
      final name = input.bandListName;
      if (name != null &&
          (band == ContextBand.morning ||
              band == ContextBand.afternoon ||
              band == ContextBand.evening)) {
        lead(_byRef(input.playlists, name));
      }
    }

    if (input.contextEnabled && input.sleeping) {
      lead(_byRef(input.playlists, 'v_instrumental'));
    }

    final ruleRef = input.rules.firstMatch(ctx)?.playlist;
    if (ruleRef != null) lead(_byRef(input.playlists, ruleRef));

    if (leads.isEmpty) return null;

    final byId = {for (final t in input.library) t.id: t};
    final tracks = <Track>[
      for (final id in leads)
        if (byId[id] != null) byId[id]!,
    ];

    final bounded = tracks.length > kDynamicMixLimit
        ? tracks.take(kDynamicMixLimit).toList(growable: false)
        : tracks;
    if (bounded.isEmpty) return null;

    return dynamicPlaylist(bounded);
  }

  static List<String> _byId(List<Playlist> playlists, String id) {
    for (final p in playlists) {
      if (p.id == id) return p.trackIds;
    }
    return const [];
  }

  static List<String> _byRef(List<Playlist> playlists, String ref) {
    final want = ref.trim().toLowerCase();
    if (want.isEmpty) return const [];
    for (final p in playlists) {
      if (p.id.toLowerCase() == want || p.name.toLowerCase() == want) {
        return p.trackIds;
      }
    }
    return const [];
  }
}
