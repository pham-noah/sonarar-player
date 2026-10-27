library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../library/lyrics.dart';
import '../theme/skin.dart';

class LyricsRow extends StatelessWidget {
  const LyricsRow({
    super.key,
    required this.skin,
    required this.onOpen,
    this.known,
  });

  final Skin skin;
  final VoidCallback onOpen;

  final Lyrics? known;

  static const Key rowKey = Key('lyrics-row');

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (known) {
      Lyrics(instrumental: true) => 'This one has no words',
      Lyrics(lines: final l) when l.isNotEmpty => 'Follows the song',
      Lyrics(plain: final p) when p != null && p.isNotEmpty => 'Words, no timing',
      Lyrics() => 'Not found',
      null => 'Tap to look up',
    };

    return GestureDetector(
      key: rowKey,
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(

          color: skin.panel,
          border: Border(left: BorderSide(color: skin.accent, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          children: [
            Icon(Icons.lyrics_outlined, size: 20, color: skin.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LYRICS',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      fontWeight: FontWeight.w800,
                      color: skin.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: skin.textSecondary,
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

const double kLyricSlot = 100.0;

class LyricsView extends StatefulWidget {
  const LyricsView({
    super.key,
    required this.skin,
    required this.lyrics,
    required this.position,
    required this.onExit,
    required this.controller,
    this.romaji = const {},
    this.onSeek,
  });

  final Skin skin;
  final Lyrics? lyrics;
  final Duration position;
  final VoidCallback onExit;
  final ScrollController controller;

  final Map<int, String> romaji;

  final ValueChanged<Duration>? onSeek;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  static const Key syncKey = Key('lyrics-sync');

  static const Key exitKey = Key('lyrics-exit');

  static const double _slot = kLyricSlot;

  int _lastLine = -1;

  bool _browsing = false;

  int? _pendingSeek;

  void _onUserScroll(ScrollUpdateNotification n) {
    if (n.dragDetails == null) return;
    if (!_browsing) setState(() => _browsing = true);
  }

  void _settle(int line, {bool jump = false}) {
    final c = widget.controller;
    if (!c.hasClients) return;
    final target = line * _slot;

    if (jump) {
      c.jumpTo(target.clamp(0.0, c.position.maxScrollExtent));
      return;
    }

    unawaited(
      c.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _sync() {
    final current = widget.lyrics?.indexAt(widget.position) ?? -1;
    setState(() {
      _browsing = false;
      _pendingSeek = null;
      _lastLine = current;
    });
    _settle(current >= 0 ? current : 0);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final lyrics = widget.lyrics;
    final position = widget.position;
    final romaji = widget.romaji;
    final lines = lyrics?.lines ?? const <LyricLine>[];
    final current = lyrics?.indexAt(position) ?? -1;

    if (_pendingSeek != null && current == _pendingSeek) _pendingSeek = null;

    if (current != _lastLine) {
      final firstPlacement = _lastLine < 0;
      _lastLine = current;
      if (!_browsing && _pendingSeek == null && current >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _settle(current, jump: firstPlacement);
        });
      }
    }

    return GestureDetector(
      key: const Key('lyrics-mode'),

      behavior: HitTestBehavior.opaque,
      child: Stack(
      children: [
        ColoredBox(
        color: skin.background.withValues(alpha: 0.30),
        child: SafeArea(
          child: lines.isEmpty
              ? _empty(context)
              : _text(lines, current, romaji),
        ),
      ),
          Positioned(
            left: 14,
            top: 8,
            child: SafeArea(
              child: GestureDetector(
                key: exitKey,
                onTap: widget.onExit,
                child: Container(
                  decoration: BoxDecoration(
                    color: skin.background.withValues(alpha: 0.55),
                    border: Border.all(color: skin.accent.withValues(alpha: 0.8), width: 1.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: skin.accent),
                      const SizedBox(width: 6),
                      Text(
                        'PLAYER',

                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontLabel,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: skin.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_browsing)
            Positioned(
              right: 18,

              bottom: 132,
              child: SafeArea(
                child: GestureDetector(
                  key: syncKey,
                  onTap: _sync,
                  child: Container(
                    decoration: BoxDecoration(
                      color: skin.background.withValues(alpha: 0.9),
                      border: Border.all(color: skin.accent, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded, size: 16, color: skin.accent),
                        const SizedBox(width: 8),
                        Text(
                          'SYNC',
                          style: TextStyle(
                            fontSize: LayoutSpec.fontLabel,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: skin.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final skin = widget.skin;
    final reason = switch (widget.lyrics) {
      null => 'No lyrics found',
      Lyrics(instrumental: true) => 'No lyrics — this is an instrumental',
      _ => 'No lyrics found',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 40, color: skin.textSecondary),
            const SizedBox(height: 14),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(List<LyricLine> lines, int current, Map<int, String> romaji) {
    const slot = kLyricSlot;

    return LayoutBuilder(
      builder: (context, box) => NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          _onUserScroll(n);
          return false;
        },
        child: ListView.builder(

          controller: widget.controller,

          padding: EdgeInsets.symmetric(vertical: (box.maxHeight - slot) / 2),
          itemExtent: slot,
          itemCount: lines.length,
          itemBuilder: (context, i) => GestureDetector(
          onTap: widget.onSeek == null
              ? null
              : () {
                  setState(() {
                    _browsing = false;
                    _pendingSeek = i;
                  });
                  widget.onSeek!(lines[i].at);
                  _settle(i);
                },
          child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              romaji[i] ?? lines[i].text,
              textAlign: TextAlign.center,

              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: i == current ? 26 : LayoutSpec.fontSmall,
                height: 1.2,
                fontWeight: i == current ? FontWeight.w900 : FontWeight.w600,
                color: i == current
                    ? Colors.white
                    : Colors.white.withValues(alpha: i < current ? 0.42 : 0.72),
                shadows: const [
                  Shadow(blurRadius: 8, offset: Offset(0, 1), color: Colors.black87),
                  Shadow(blurRadius: 22, color: Colors.black54),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }
}
