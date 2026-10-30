library;

import 'package:flutter/material.dart';

import '../library/history.dart';
import '../library/play_log.dart';
import '../library/track.dart';
import '../theme/slab.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../widgets/kit.dart';
import '../widgets/pressable.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.skin,
    required this.events,
    required this.tracks,
    this.today,
    this.inline = false,
    this.ranks,

    this.contextEnabled = true,
  });

  final bool contextEnabled;

  final Skin skin;
  final List<PlayEvent> events;
  final List<Track> tracks;

  final DateTime? today;

  final Widget? ranks;

  final bool inline;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month;
  DayShape? _selected;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();

    final withPlays = monthsWithPlays(widget.events);
    _month =
        withPlays.isNotEmpty ? withPlays.first : DateTime(now.year, now.month);
  }

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final h = buildHistory(widget.events, year: _month.year, month: _month.month);
    final byId = {for (final t in widget.tracks) t.id: t};

    final list = ListView(

          padding: widget.inline
              ? const EdgeInsets.fromLTRB(20, 8, 20, 24)
              : LayoutSpec.screenPadding,
          children: [
            if (!widget.inline) const SizedBox(height: 4),

            if (h.totalPlays == 0 && h.month.isEmpty)
              Text(
                'Nothing played yet.',
                style: TextStyle(
                  fontSize: LayoutSpec.fontBase,
                  color: skin.textPrimary,
                  height: 1.4,
                ),
              )
            else ...[
              _monthBar(skin, h),
              const SizedBox(height: 10),
              _heatGrid(skin, h.month),

              if (_selected != null && !_selected!.isEmpty) ...[
                const SizedBox(height: 16),
                _dayDetail(skin, _selected!, byId),
              ],

              if (h.thinSample)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    'Only ${h.totalPlays} play${h.totalPlays == 1 ? '' : 's'} so '
                    'far — the shapes below are real, just small.',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: skin.accent,
                      height: 1.4,
                    ),
                  ),
                ),

              const SizedBox(height: 22),

              _listened(skin, h),

              const SizedBox(height: 22),
              SectionLabel(skin: skin, text: 'TOP TRACKS'),
              _topTracks(skin, h, byId),

              const SizedBox(height: 22),

              if (widget.contextEnabled) ...[
                SectionLabel(skin: skin, text: 'BY TIME OF DAY'),
                _bandChart(skin, h.byBand, msByBand: h.msByBand),
              ],

            ],

            if (widget.ranks != null) ...[
              const SizedBox(height: 26),
              widget.ranks!,
            ],
            const SizedBox(height: 24),
          ],
        );

    if (widget.inline) return list;
    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(child: list),
    );
  }

  Widget _monthBar(Skin skin, HistoryShape h) => KitRow(
        skin: skin,
        label: 'MONTH',
        icon: Icons.calendar_month_rounded,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chevron(skin, Icons.chevron_left_rounded, () {
              setState(() {
                _month = previousMonth(_month);
                _selected = null;
              });
            }),
            const SizedBox(width: 4),
            Text(
              '${_monthName(_month.month)} ${h.month.year}'.toUpperCase(),
              style: TextStyle(
                fontSize: LayoutSpec.fontFloor - 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: skin.accent,
              ),
            ),
            const SizedBox(width: 4),
            _chevron(skin, Icons.chevron_right_rounded, () {
              setState(() {
                _month = nextMonth(_month);
                _selected = null;
              });
            }),
          ],
        ),
      );

  Widget _chevron(Skin skin, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: skin.textPrimary, size: 26),
        ),
      );

  Widget _heatGrid(Skin skin, MonthShape month) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final rows = <Widget>[];
    var cells = <Widget>[];

    final firstWeekday = month.days.first.date.weekday;
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const Expanded(child: SizedBox()));
    }

    for (final day in month.days) {
      cells.add(Expanded(child: _cell(skin, day, month.peakPlays)));
      if (cells.length == 7) {
        rows.add(Row(children: cells));
        rows.add(const SizedBox(height: 5));
        cells = <Widget>[];
      }
    }
    if (cells.isNotEmpty) {
      while (cells.length < 7) {
        cells.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: cells));
    }

    return Column(
      children: [
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    fontWeight: FontWeight.w800,
                    color: skin.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        ...rows,
      ],
    );
  }

  Widget _cell(Skin skin, DayShape day, int peak) {
    final isToday = day.date.year == _today.year &&
        day.date.month == _today.month &&
        day.date.day == _today.day;
    final selected = _selected?.date == day.date;
    final t = day.intensity(peak);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Pressable(
        child: InkWell(
          onTap: () => setState(() => _selected = day),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(

              color: day.isEmpty
                  ? Colors.transparent
                  : skin.accent.withValues(alpha: 0.12 + 0.6 * t),
              border: Border.all(
                color: selected
                    ? skin.accent
                    : isToday
                        ? skin.primaryText(0.7)
                        : skin.secondary(0.2),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              '${day.date.day}',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,

                fontWeight: day.isEmpty ? FontWeight.w400 : FontWeight.w900,
                color: day.isEmpty
                    ? skin.secondary(0.55)

                    : t > 0.6
                        ? skin.background
                        : skin.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayDetail(
    Skin skin,
    DayShape day,
    Map<String, Track> byId,
  ) {
    final track = day.mostPlayedTrackId == null
        ? null
        : byId[day.mostPlayedTrackId];
    final bandPeak = day.byBand.values.isEmpty
        ? 1
        : day.byBand.values.reduce((a, b) => a > b ? a : b);

    return Slab(
        presentation: PresentationScope.of(context, fallback: skin),
      skin: skin,

      fill: skin.background,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${day.date.day} ${_monthName(day.date.month)}',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    color: skin.accent,
                  ),
                ),
              ),

              if (day.knownWeather > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      day.playedInTheRain > day.playedDry
                          ? Icons.water_drop_rounded
                          : Icons.wb_sunny_rounded,
                      size: 15,
                      color: skin.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${day.playedInTheRain} in rain',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        color: skin.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          for (final b in kBandOrder)
            if ((day.byBand[b] ?? 0) > 0)
              _bandBar(skin, b, day.byBand[b]!, bandPeak, compact: true),

          const SizedBox(height: 8),
          Text(
            track?.title ?? day.mostPlayedTrackId ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontSmall,
              fontWeight: FontWeight.w800,
              color: skin.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_shortDuration(day.listenedMs)} · '
            '${day.plays} play${day.plays == 1 ? '' : 's'} · '
            '${day.completions} through',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDuration(int ms) {
    final total = (ms / 1000).round();
    if (total < 60) return '${total}s';
    if (total < 3600) return '${total ~/ 60}m';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Widget _listened(Skin skin, HistoryShape h) {
    if (h.listenedMs <= 0) return const SizedBox.shrink();
    final days = h.recentDays.isEmpty ? 0 : h.recentDays.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(skin: skin, text: 'TIME LISTENED'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _shortDuration(h.listenedMs),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: skin.textPrimary,
              ),
            ),
            if (days > 0) ...[
              const SizedBox(width: 10),
              Text(
                'across $days day${days == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: LayoutSpec.fontLabel,
                  color: skin.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _topTracks(Skin skin, HistoryShape h, Map<String, Track> byId) {
    final ranked = h.playsByTrack.keys.toList()
      ..sort((a, b) {
        final ta = h.msByTrack[a] ?? 0;
        final tb = h.msByTrack[b] ?? 0;
        if (ta != tb) return tb.compareTo(ta);
        return (h.playsByTrack[b] ?? 0).compareTo(h.playsByTrack[a] ?? 0);
      });
    if (ranked.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final id in ranked.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    byId[id]?.title ?? id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontBase,
                      fontWeight: FontWeight.w700,
                      color: skin.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(

                  (h.msByTrack[id] ?? 0) > 0
                      ? _shortDuration(h.msByTrack[id]!)
                      : '${h.playsByTrack[id]}×',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontLabel,
                    fontWeight: FontWeight.w900,
                    color: skin.accent,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ignore: unused_element
  Widget _discovery(Skin skin, DiscoverySplit d) {
    final share = d.newShare ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: skin.accent),
            const SizedBox(width: 7),
            Text(
              '${(share * 100).round()}% new',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${d.newTracks} new · ${d.repeatTracks} known',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ClipRect(
          child: Row(
            children: [
              Expanded(
                flex: (d.newTracks * 1000 / (d.total == 0 ? 1 : d.total)).round(),
                child: Container(height: 10, color: skin.accent),
              ),
              Expanded(
                flex: (d.repeatTracks * 1000 / (d.total == 0 ? 1 : d.total)).round(),
                child: Container(height: 10, color: skin.panel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bandChart(
    Skin skin,
    List<(String, int)> bands, {
    Map<String, int> msByBand = const {},
  }) {
    if (bands.isEmpty) return const SizedBox.shrink();

    final usesTime = msByBand.isNotEmpty;
    final values = usesTime
        ? {for (final b in bands) b.$1: (msByBand[b.$1] ?? 0)}
        : {for (final b in bands) b.$1: b.$2};
    final peak = values.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final b in bands)
          _bandBar(skin, b.$1, values[b.$1] ?? 0, peak, asTime: usesTime),
      ],
    );
  }

  Widget _bandBar(
    Skin skin,
    String band,
    int count,
    int peak, {
    bool compact = false,
    bool asTime = false,
  }) {
    final frac = peak <= 0 ? 0.0 : count / peak;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 74 : 84,
            child: Text(
              _bandName(band),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                fontWeight: FontWeight.w800,
                color: skin.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [

                Container(
                  height: compact ? 10 : 14,
                  decoration: BoxDecoration(
                    color: skin.secondary(0.15),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: frac.clamp(0.0, 1.0),
                  child: Container(
                    height: compact ? 10 : 14,
                    color: skin.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(

            width: asTime ? 44 : 30,
            child: Text(
              asTime ? _shortDuration(count) : '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                fontWeight: FontWeight.w800,
                color: skin.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _bandName(String band) => switch (band) {
      'morning' => 'MORNING',
      'afternoon' => 'AFTERNOON',
      'evening' => 'EVENING',
      'night' => 'NIGHT',
      'darkHour' => 'NIGHT HOUR',
      _ => band.toUpperCase(),
    };

String _monthName(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ][m - 1];
