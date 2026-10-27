library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ytdlp_flutter/ytdlp_flutter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../library/downloaded_tracks.dart';
import '../library/playlist_read.dart';
import '../library/playlists.dart';
import '../theme/skin.dart';
import '../theme/layout.dart';

class PlaylistSource {
  const PlaylistSource({
    required this.folder,
    required this.label,
    required this.playlistId,
    this.url = '',
  });

  final String folder;

  final String label;

  final String playlistId;

  final String url;

  PlaylistSource copyWith({String? label, String? playlistId, String? url}) => PlaylistSource(
        folder: folder,
        label: label ?? this.label,
        playlistId: playlistId ?? this.playlistId,
        url: url ?? this.url,
      );

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'id': playlistId,
        'label': label,
        'url': url,
      };

  static PlaylistSource? fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final label = (j['label'] as String?)?.trim() ?? '';

    if (id.isEmpty || label.isEmpty) return null;
    final folder = (j['folder'] as String?)?.trim() ?? '';
    return PlaylistSource(
      folder: folder.isEmpty ? label : folder,
      label: label,
      playlistId: id,
      url: (j['url'] as String?) ?? '',
    );
  }
}

class PlaylistSources {
  PlaylistSources(this.file);

  final File file;

  Future<List<PlaylistSource>> load() async {
    try {
      if (!await file.exists()) return const [];
      final raw = jsonDecode(await file.readAsString());
      final list = (raw is Map ? raw['playlists'] : raw) as List<dynamic>?;
      if (list == null) return const [];
      final out = <PlaylistSource>[];
      for (final e in list) {
        if (e is Map) {
          final s = PlaylistSource.fromJson(Map<String, dynamic>.from(e));
          if (s != null) out.add(s);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> save(List<PlaylistSource> sources) async {
    try {
      if (file.parent.path.isEmpty) return false;
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode({
        'playlists': [for (final s in sources) s.toJson()],
      }));
      return true;
    } catch (_) {
      return false;
    }
  }
}

String? playlistIdFrom(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return null;
  if (t.contains('list=')) {
    final v = t.split('list=').last.split('&').first.trim();
    return v.isEmpty ? null : v;
  }

  if (t.length >= 13 && !t.contains('/') && !t.contains(' ')) return t;
  return null;
}

class PlaylistManagerSheet extends StatefulWidget {
  const PlaylistManagerSheet({
    super.key,
    required this.skin,
    required this.store,
    required this.downloadDir,
    this.manifest,
    this.onImported,
    this.onEnsurePlaylist,
    this.onAddToPlaylist,
  });

  final Skin skin;
  final PlaylistSources store;

  final Directory downloadDir;

  final File? manifest;

  final void Function(String path)? onImported;

  final Playlist Function(String name)? onEnsurePlaylist;

  final void Function(Playlist playlist, String trackId)? onAddToPlaylist;

  @override
  State<PlaylistManagerSheet> createState() => _PlaylistManagerSheetState();
}

class _PlaylistManagerSheetState extends State<PlaylistManagerSheet> {
  final _yt = YoutubeExplode();

  List<PlaylistSource> _sources = const [];
  bool _loading = true;

  final Map<String, String> _status = {};
  final Set<String> _busy = {};

  final Map<String, String> _nowTitle = {};
  final Map<String, String> _nowId = {};

  final Map<String, double?> _frac = {};

  final Map<String, int> _bytes = {};

  final Map<String, int> _seen = {};
  final Map<String, int> _total = {};

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _sources = s;
      _loading = false;
    });
  }

  Future<void> _persist(List<PlaylistSource> next) async {
    setState(() => _sources = next);
    final ok = await widget.store.save(next);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saved for now, but it could not be written to disk.'),
      ));
    }
  }

  Set<String> _alreadyHere() {
    if (!widget.downloadDir.existsSync()) return {};
    return {
      for (final f in widget.downloadDir.listSync())
        if (f is File)
          f.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
    };
  }

  Future<void> _run(PlaylistSource src) async {
    final key = src.folder;
    if (_busy.contains(key)) return;
    setState(() {
      _busy.add(key);
      _status[key] = 'reading the playlist…';
    });

    var added = 0, skipped = 0, failed = 0;

    final Playlist? target = widget.onEnsurePlaylist?.call(src.label);

    Timer? poller;
    var pollTick = false;
    poller = Timer.periodic(const Duration(milliseconds: 350), (_) async {
      if (!mounted || !_busy.contains(key)) {
        poller?.cancel();
        return;
      }

      if (pollTick) return;
      pollTick = true;
      try {
        final id = _nowId[key];
        if (id == null) return;
        var total = 0;
        await for (final e in widget.downloadDir.list()) {
          if (e is! File) continue;
          if (!e.uri.pathSegments.last.contains(id)) continue;
          total += await e.length();
        }
        if (mounted && total > 0 && _busy.contains(key)) {
          setState(() => _bytes[key] = total);
        }
      } catch (_) {
      } finally {
        pollTick = false;
      }
    });

    try {
      final videos = await readPlaylistVideos(
        playlistId: src.playlistId,
        fetch: (url) async {
          final bytes = await httpGetBytes(url);
          return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
        },
      );
      await Ytdlp.init();
      final already = _alreadyHere();
      if (videos.isEmpty) {
        if (mounted) {
          setState(() => _status[key] =
              'Could not read any videos from that playlist — check the link, or the playlist may be empty.');
        }
        return;
      }
      if (mounted) {
        setState(() {
          _total[key] = videos.length;
          _seen[key] = 0;
        });
      }

      for (final v in videos) {
        if (!mounted) return;

        if (already.contains(v.id)) {
          skipped++;
          if (mounted) {
            setState(() {
              _seen[key] = (_seen[key] ?? 0) + 1;
              _status[key] = 'added $added · skipped $skipped · failed $failed';
            });
          }
          continue;
        }
        if (mounted) {
          setState(() {
            _status[key] = 'added $added · skipped $skipped · failed $failed';

            _nowTitle[key] = v.title;
            _nowId[key] = v.id;
            _frac[key] = null;
            _bytes[key] = 0;
          });
        }
        try {
          final path = await Ytdlp.downloadAudio(
            url: 'https://www.youtube.com/watch?v=${v.id}',
            outputDir: widget.downloadDir.path,
            taskId: v.id,

            onProgress: (pr) {
              if (!mounted) return;
              setState(() => _frac[key] = pr.fraction);
            },

            audioFormat: 'm4a',
          );
          final f = File(path);

          if (await f.length() == 0) {
            try {
              await f.delete();
            } catch (_) {}
            failed++;
            continue;
          }

          final track = await describeDownload(
            audio: f,
            videoTitle: v.title,
            channel: v.author,
            videoId: v.id,
            downloadDir: widget.downloadDir,
            fetchThumbnail: httpGetBytes,
            thumbnailUrl: v.thumbnailUrl,
            durationSeconds: (v.duration ?? Duration.zero).inSeconds,
          );
          if (track != null && widget.manifest != null) {
            await addToManifest(manifest: widget.manifest!, track: track);
          }

          if (track != null && target != null) {
            widget.onAddToPlaylist?.call(target, track.id);
          }
          widget.onImported?.call(path);
          added++;
          if (mounted) {
            setState(() {
              _seen[key] = (_seen[key] ?? 0) + 1;
              _nowTitle.remove(key);
              _nowId.remove(key);
              _frac.remove(key);
              _bytes.remove(key);
            });
          }
        } catch (_) {
          failed++;
        }
      }
      if (mounted) {
        setState(() => _status[key] = 'added $added · skipped $skipped · failed $failed');
      }
    } catch (e) {
      if (mounted) setState(() => _status[key] = 'Could not read it: $e');
    } finally {
      poller.cancel();
      if (mounted) {
        setState(() {
          _busy.remove(key);

          _nowTitle.remove(key);
          _nowId.remove(key);
          _frac.remove(key);
          _bytes.remove(key);
          _seen.remove(key);
          _total.remove(key);
        });
      }
    }
  }

  Future<void> _edit({PlaylistSource? existing}) async {
    final labelCtl = TextEditingController(text: existing?.label ?? '');
    final linkCtl = TextEditingController(
      text: existing == null ? '' : (existing.url.isNotEmpty ? existing.url : existing.playlistId),
    );
    final skin = widget.skin;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: skin.background,
        title: Text(
          existing == null ? 'NEW PLAYLIST' : 'EDIT PLAYLIST',
          style: TextStyle(
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: skin.accent,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtl,
              style: TextStyle(fontSize: 16, color: skin.textPrimary),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: skin.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkCtl,
              style: TextStyle(fontSize: 16, color: skin.textPrimary),
              decoration: InputDecoration(
                labelText: 'Playlist link',
                labelStyle: TextStyle(color: skin.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: TextStyle(color: skin.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('SAVE', style: TextStyle(color: skin.accent)),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final label = labelCtl.text.trim();
    final id = playlistIdFrom(linkCtl.text);

    if (label.isEmpty || id == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          label.isEmpty ? 'A playlist needs a name' : 'That link has no playlist id in it',
        ),
      ));
      return;
    }

    final next = [..._sources];
    if (existing == null) {
      if (next.any((s) => s.label.toLowerCase() == label.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You already have a playlist called "$label"')),
        );
        return;
      }
      next.add(PlaylistSource(
        folder: label,
        label: label,
        playlistId: id,
        url: linkCtl.text.trim(),
      ));
    } else {
      final i = next.indexWhere((s) => s.folder == existing.folder);

      if (i >= 0) {
        next[i] = existing.copyWith(
          label: label,
          playlistId: id,
          url: linkCtl.text.trim(),
        );
      }
    }
    await _persist(next);
  }

  Future<void> _remove(PlaylistSource src) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PresentationScope.uiSkin(context, widget.skin).background,
        title: Text('REMOVE "${src.label}"?',
            style: TextStyle(
                fontSize: 18,
                color: PresentationScope.uiSkin(context, widget.skin).textPrimary)),
        content: Text('The downloaded files stay — this only forgets the source.',
            style: TextStyle(
                fontSize: 16,
                color: PresentationScope.uiSkin(context, widget.skin).textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('KEEP', style: TextStyle(color: widget.skin.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('REMOVE', style: TextStyle(color: widget.skin.textSecondary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _persist([for (final s in _sources) if (s.folder != src.folder) s]);
  }

  String _progressTextOf(String key) {
    final f = _frac[key];
    if (f != null) return '${(f * 100).round()}%';
    final b = _bytes[key] ?? 0;
    if (b > 0) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '…';
  }

  double? _overallOf(String key) {
    final total = _total[key];
    if (total == null || total == 0) return null;
    return ((_seen[key] ?? 0) / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IMPORTED PLAYLISTS',
              style: TextStyle(
                fontSize: 18,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: skin.accent,
              )),
          const SizedBox(height: 4),
          Text('Import one, or update it later — only the new songs are fetched.',
              style: TextStyle(fontSize: 16, color: skin.textSecondary)),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_sources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('No playlists yet. Add one below.',
                  style: TextStyle(fontSize: 16, color: skin.textSecondary)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sources.length,
                itemBuilder: (_, i) => _row(skin, _sources[i]),
              ),
            ),

          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _edit(),
              icon: Icon(Icons.add_rounded, color: skin.accent),
              label: Text('NEW PLAYLIST',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: skin.accent,
                  )),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: skin.accent.withValues(alpha: 0.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Skin skin, PlaylistSource src) {
    final busy = _busy.contains(src.folder);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(src.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: skin.textPrimary,
                        )),
                  ],
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => _edit(existing: src),
                icon: Icon(Icons.edit_outlined, size: 20, color: skin.textSecondary),
                tooltip: 'Edit name and link',
              ),
              IconButton(
                onPressed: busy ? null : () => _remove(src),
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: skin.textSecondary),
                tooltip: 'Remove',
              ),

              IconButton(
                onPressed: busy ? null : () => _run(src),
                icon: busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.download_rounded, color: skin.accent),
                tooltip: 'Import or update — only new songs are fetched',
              ),
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 5),
            if (_nowTitle[src.folder] != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _nowTitle[src.folder]!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: skin.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _progressTextOf(src.folder),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: skin.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],

            ClipRect(
              child: LinearProgressIndicator(
                value: _overallOf(src.folder),
                color: skin.accent,
                backgroundColor: skin.panel,
                minHeight: 4,
              ),
            ),
            if (_total[src.folder] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 2),
                child: Text(
                  '${_seen[src.folder] ?? 0} of ${_total[src.folder]}',
                  style: TextStyle(fontSize: 14, color: skin.textSecondary),
                ),
              ),
          ],
          if (_status[src.folder] != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 2),
              child: Text(_status[src.folder]!,
                  style: TextStyle(fontSize: 16, color: skin.textSecondary)),
            ),
        ],
      ),
    );
  }
}
