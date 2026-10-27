library;

import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/constants.dart';
import 'playlists.dart';

class PlaylistLoader {
  PlaylistLoader({required this.store, AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final PlaylistStore store;
  final AssetBundle _bundle;

  Future<PlaylistList> load({required Set<String> libraryIds}) async {
    final existing = await store.load();
    final seeded = await _fromBundle();

    if (existing.isEmpty) {
      if (seeded == null) return PlaylistList();
      _pruneAndReport(seeded, libraryIds);
      try {
        await store.save(seeded);
      } on FileSystemException {
        // ignore: empty_catches
      }
      return seeded;
    }

    _pruneAndReport(existing, libraryIds);

    if (seeded == null) return existing;

    final known = {for (final p in existing.all) p.id};
    final added = <Playlist>[];
    for (final p in seeded.all) {
      if (!known.contains(p.id)) added.add(p);
    }

    if (added.isEmpty) {
      return existing;
    }

    final merged = PlaylistList([...existing.all, ...added]);
    _pruneAndReport(merged, libraryIds);
    try {
      await store.save(merged);
    } on FileSystemException {
      // ignore: empty_catches
    }
    return merged;
  }

  Future<PlaylistList?> _fromBundle() async {
    try {
      final raw = await _bundle.loadString(kBundledPlaylists);
      return PlaylistList([
        ...PlaylistStore.decode(raw).all,
      ]);
    } catch (_) {
      return null;
    }
  }

  void _pruneAndReport(PlaylistList lists, Set<String> libraryIds) {
    lists.prune(libraryIds);
    lists.dropEmptySeeds();
  }

  Future<void> save(PlaylistsView lists) => store.save(lists);
}
