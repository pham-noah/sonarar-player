library;

import 'package:flutter/material.dart';

import '../library/compendium.dart';
import '../library/track.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../widgets/stagger_in.dart';

class CompendiumScreen extends StatefulWidget {
  const CompendiumScreen({
    super.key,
    required this.skin,
    this.presentation,
    required this.entries,
    this.onSummon,
    this.playingTrackId,
    this.inline = false,
  });

  final Skin skin;

  final Presentation? presentation;
  final List<CompendiumEntry> entries;

  final void Function(Track)? onSummon;

  final String? playingTrackId;

  final bool inline;

  @override
  State<CompendiumScreen> createState() => _CompendiumScreenState();
}

enum _Order { heard, recent, name }

List<CompendiumEntry> orderCompendium(List<CompendiumEntry> entries, int orderIndex) {
  final out = entries.toList();
  switch (orderIndex) {
    case 1:

      out.sort((a, b) {
        final x = a.lastPlayedAt;
        final y = b.lastPlayedAt;
        if (x == null && y == null) return a.track.title.compareTo(b.track.title);
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });
    case 2:
      out.sort((a, b) => a.track.title.compareTo(b.track.title));
    default:
      out.sort((a, b) {
        final c = b.plays.compareTo(a.plays);
        return c != 0 ? c : a.track.title.compareTo(b.track.title);
      });
  }
  return out;
}

List<Widget> compendiumSliverList({
  required Skin skin,
  required List<CompendiumEntry> rows,
  required String? playingTrackId,
  required void Function(Track)? onSummon,
}) =>
    [
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nothing has been heard yet, so the compendium is empty. It fills itself as you listen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: LayoutSpec.fontBase,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => StaggerIn(

            index: i,
            style: StaggerStyle.drop,
            child: compendiumRow(
              skin: skin,
              entry: rows[i],
              playing: rows[i].track.id == playingTrackId,
              onSummon: onSummon,
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];

Widget compendiumRow({
  required Skin skin,
  required CompendiumEntry entry,
  required bool playing,
  required void Function(Track)? onSummon,
  Presentation? presentation,
}) {
  final t = entry.track;
  final at = entry.lastPlayedAt;
  final when = at == null
      ? ''
      : ' \u00b7 ${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Slab(
        presentation: presentation,
      skin: skin,
      padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontSmall,
                    fontWeight: FontWeight.w700,
                    color: playing ? skin.accent : skin.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.neverHeard ? 'Not heard yet' : '${entry.plays}x$when',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: LayoutSpec.fontLabel, color: skin.textSecondary),
                ),
              ],
            ),
          ),
          if (onSummon != null)
            IconButton(
              onPressed: () => onSummon(t),
              icon: Icon(Icons.add_circle_outline_rounded, color: skin.accent, size: 22),
              tooltip: 'Add to queue',
            ),
        ],
      ),
    ),
  );
}

class _CompendiumScreenState extends State<CompendiumScreen> {
  _Order _order = _Order.heard;

  List<CompendiumEntry> get _visible =>
      orderCompendium(widget.entries, _order.index);

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final rows = _visible;
    final neverHeard = widget.entries.where((e) => e.neverHeard).length;

    final header = [
      if (!widget.inline)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: ScreenTitle(skin: skin, text: 'CATALOGUE'),
        ),

      Padding(
        padding: EdgeInsets.fromLTRB(20, widget.inline ? 10 : 2, 20, 12),
        child: Text(
          '${widget.entries.length - neverHeard} of '
          '${widget.entries.length} heard',
          style: TextStyle(
            fontSize: LayoutSpec.fontSmall,
            color: skin.textSecondary,
          ),
        ),
      ),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: SkinChip(
                skin: skin,
                label: 'MOST HEARD',
                selected: _order == _Order.heard,
                onTap: () => setState(() => _order = _Order.heard),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SkinChip(
                skin: skin,
                label: 'RECENT',
                selected: _order == _Order.recent,
                onTap: () => setState(() => _order = _Order.recent),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SkinChip(
                skin: skin,
                label: 'A–Z',
                selected: _order == _Order.name,
                onTap: () => setState(() => _order = _Order.name),
              ),
            ),
          ],
        ),
      ),
      if (widget.entries.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nothing has been heard yet, so the compendium is empty. '
            'It fills itself as you listen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: LayoutSpec.fontBase,
              color: skin.textSecondary,
              height: 1.4,
            ),
          ),
        )
      else
        for (var i = 0; i < rows.length; i++)
          StaggerIn(
            index: i,
            style: StaggerStyle.drop,
            child: _row(skin, rows[i]),
          ),
      const SizedBox(height: 24),
    ];

    final list = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      shrinkWrap: widget.inline,
      physics: widget.inline
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      children: header,
    );

    if (widget.inline) return list;
    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(child: list),
    );
  }

  Widget _row(Skin skin, CompendiumEntry e) {
    final playing = e.track.id == widget.playingTrackId;
    final summonable = widget.onSummon != null;

    final dim = e.neverHeard;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slab(
        presentation: PresentationScope.of(context, fallback: skin),
        skin: skin,
        active: playing,
        fill: playing ? null : skin.background,
        onTap: !summonable || dim ? null : () => widget.onSummon!(e.track),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [

            SizedBox(
              width: 42,
              child: Text(
                dim ? '—' : '${e.plays}',
                style: TextStyle(
                  fontSize: LayoutSpec.fontBase,
                  fontWeight: FontWeight.w900,
                  color: dim
                      ? skin.textSecondary.withValues(alpha: 0.5)
                      : (playing ? skin.onAccent : skin.accent),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w700,
                      color: dim
                          ? skin.textSecondary.withValues(alpha: 0.6)
                          : (playing ? skin.onAccent : skin.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(

                    dim
                        ? 'never heard'
                        : 'last ${_ago(e.lastPlayedAt!, DateTime.now())}'
                            '${e.completions > 0 ? ' · ${e.completions} through' : ''}',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: playing
                          ? skin.onAccent.withValues(alpha: 0.8)
                          : skin.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (playing)
              Icon(Icons.volume_up_rounded, size: 18, color: skin.onAccent)
            else if (summonable && !dim)
              Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }
}

String _ago(DateTime then, DateTime now) {
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(then.year, then.month, then.day))
      .inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 30) return '$days days ago';
  final months = days ~/ 30;
  return months == 1 ? 'a month ago' : '$months months ago';
}
