import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/music_root.dart';
import '../theme/skin.dart';

/// Picks the folder the library is read from.
///
/// A plain directory browser rather than a system picker: the app already holds
/// broad storage access and reads real paths, and a document-tree URI would
/// give it a handle `dart:io` cannot open. Directories only, and a folder can
/// only be chosen when it actually holds a library manifest.
class MusicFolderScreen extends StatefulWidget {
  const MusicFolderScreen({
    super.key,
    required this.skin,
    required this.current,
  });

  final Skin skin;
  final String current;

  static const List<String> roots = [
    '/storage/emulated/0',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/sdcard',
  ];

  @override
  State<MusicFolderScreen> createState() => _MusicFolderScreenState();
}

class _MusicFolderScreenState extends State<MusicFolderScreen> {
  late String _path = widget.current;
  List<Directory> _dirs = const [];
  bool _isLibrary = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_open(_path));
  }

  Future<void> _open(String path) async {
    setState(() => _busy = true);
    final dir = Directory(path);
    var children = const <Directory>[];
    try {
      children = await dir
          .list()
          .where((e) => e is Directory && !_isHidden(e.path))
          .cast<Directory>()
          .toList()
        ..sort((a, b) => _name(a.path).toLowerCase().compareTo(
            _name(b.path).toLowerCase()));
    } catch (_) {
      children = const [];
    }
    final isLib = await MusicRoot.isLibrary(path);
    if (!mounted) return;
    setState(() {
      _path = path;
      _dirs = children;
      _isLibrary = isLib;
      _busy = false;
    });
  }

  static bool _isHidden(String path) {
    final name = _name(path);
    return name.startsWith('.');
  }

  static String _name(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }

  static String _jumpLabel(String path) => switch (path) {
        '/storage/emulated/0' => 'INTERNAL',
        '/storage/emulated/0/Music' => 'MUSIC',
        '/storage/emulated/0/Download' => 'DOWNLOAD',
        '/sdcard' => 'SDCARD',
        _ => path.split('/').last,
      };

  String? get _parent {
    if (_path == '/' || _path.isEmpty) return null;
    final cut = _path.lastIndexOf(Platform.pathSeparator);
    return cut <= 0 ? '/' : _path.substring(0, cut);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    return Scaffold(
      backgroundColor: skin.background,
      appBar: AppBar(
        backgroundColor: skin.background,
        foregroundColor: skin.textPrimary,
        title: Text(
          'MUSIC FOLDER',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
            color: skin.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  if (_parent != null)
                    IconButton(
                      key: const Key('music-folder-up'),
                      onPressed: () => _open(_parent!),
                      icon: Icon(Icons.arrow_upward_rounded,
                          size: 18, color: skin.accent),
                    ),
                  Expanded(
                    child: Text(
                      _path,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontMicro,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final root in MusicFolderScreen.roots)
                  if (root != _path && Directory(root).existsSync())
                    TextButton(
                      key: Key('music-folder-jump-$root'),
                      onPressed: () => _open(root),
                      style: TextButton.styleFrom(
                        foregroundColor: skin.accent,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _jumpLabel(root),
                        style: const TextStyle(
                          fontSize: LayoutSpec.fontMicro,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
              ],
            ),
            Expanded(
              child: _busy
                  ? Center(
                      child: Icon(Icons.folder_open_rounded,
                          size: 28, color: skin.textSecondary))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _dirs.length,
                      itemBuilder: (_, i) {
                        final dir = _dirs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            key: Key('music-folder-${_name(dir.path)}'),
                            onTap: () => _open(dir.path),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              decoration: BoxDecoration(
                                color: skin.panel,
                                border: Border(
                                  left: BorderSide(
                                      color: skin.accentAt(0.6),
                                      width: 3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.folder_rounded,
                                      size: 17, color: skin.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _name(dir.path),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: skin.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  Text(
                    _isLibrary
                        ? 'This folder holds library_manifest.json.'
                        : 'No library_manifest.json here — the app cannot read it as a library.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontMicro,
                      color: _isLibrary ? skin.accent : skin.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const Key('music-folder-use'),
                      onPressed: _isLibrary
                          ? () => Navigator.of(context).pop(_path)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: skin.accent,
                        foregroundColor: skin.onAccent,
                        disabledBackgroundColor:
                            skin.panel.withValues(alpha: 0.6),
                        disabledForegroundColor: skin.textSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      child: const Text(
                        'USE THIS FOLDER',
                        style: TextStyle(
                          fontSize: LayoutSpec.fontMicro,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
