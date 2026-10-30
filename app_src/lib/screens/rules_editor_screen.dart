library;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../library/playlists.dart';
import '../rules/context_rules.dart';
import '../theme/skin.dart';
import '../theme/skin_policy.dart';
import '../widgets/pressable.dart';

class RulesEditorScreen extends StatelessWidget {
  const RulesEditorScreen({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final AppState state;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final rules = state.contextRules;
    final active = state.activeRule;

    return ColoredBox(
      color: skin.background,
      child: SafeArea(
        child: ListView(
          padding: LayoutSpec.screenPadding,
          children: [
            Text(
              'CONTEXT RULES',
              style: TextStyle(
                fontSize: LayoutSpec.fontTitle,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When the context matches one of these, its playlist becomes the '
              'queue. Highest priority that matches wins; if nothing matches, '
              'the player picks by itself as it always has.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            _activeNow(skin, active),

            const SizedBox(height: 22),
            if (rules.isEmpty)
              Text(
                'No rules. That is a working state — the context still picks '
                'music, it just has nothing extra to say about it.',
                style: TextStyle(
                  fontSize: LayoutSpec.fontSmall,
                  color: skin.textSecondary,
                  height: 1.4,
                ),
              )
            else
              for (final r in rules.rules) _ruleRow(skin, r, active),

            const SizedBox(height: 20),
            _addButton(context, skin),

            const SizedBox(height: 18),
            Text(
              'Rules can also be edited as plain JSON in rules.json beside the '
              'other state files. The app reads that file at launch.',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.secondary(0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Not offered here: place rules, and a "dry" weather condition — '
              'the app reports unknown weather as not-raining, so a dry rule '
              'would fire on the day it knows least.',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                color: skin.secondary(0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _activeNow(Skin skin, ContextRule? active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: active == null
                ? skin.secondary(0.3)
                : skin.accent,
            width: active == null ? 1 : 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTING NOW',
              style: TextStyle(
                fontSize: LayoutSpec.fontLabel,
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
                color: skin.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(

              active == null
                  ? 'No rule matches right now — the player is choosing on its '
                      'own. That is the normal case.'
                  : '${active.id}: ${active.describe()}',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );

  Widget _ruleRow(Skin skin, ContextRule r, ContextRule? active) {
    final isActive = active?.id == r.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive
                ? skin.accent
                : skin.secondary(0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.describe(),
                    style: TextStyle(
                      fontSize: LayoutSpec.fontSmall,
                      fontWeight: FontWeight.w700,
                      color: skin.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'priority ${r.priority}'
                    '${isActive ? " · ACTING NOW" : ""}',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      letterSpacing: 1.5,
                      color: isActive ? skin.accent : skin.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _adjust(skin, r, 10),
              icon: Icon(Icons.keyboard_arrow_up_rounded,
                  color: skin.textPrimary),
              tooltip: 'More important',
            ),
            IconButton(
              onPressed: () => _adjust(skin, r, -10),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: skin.textPrimary),
              tooltip: 'Less important',
            ),
            IconButton(
              onPressed: () => _delete(skin, r),
              icon: Icon(Icons.delete_outline_rounded, color: skin.accent),
              tooltip: 'Remove this rule',
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context, Skin skin) => Pressable(
        child: OutlinedButton(
          onPressed: () => _add(context, skin),
          style: OutlinedButton.styleFrom(
            foregroundColor: skin.accent,
            side: BorderSide(color: skin.accent),
            minimumSize: const Size.fromHeight(LayoutSpec.tapTarget),
          ),
          child: const Text('ADD A RULE'),
        ),
      );

  void _commit(List<ContextRule> rules) {
    state.setContextRules(ContextRules(rules));
    onChanged();
  }

  void _adjust(Skin skin, ContextRule r, int delta) {
    final next = [
      for (final other in state.contextRules.rules)
        if (other.id == r.id)
          ContextRule(
            id: r.id,
            priority: r.priority + delta,
            band: r.band,
            weather: r.weather,
            mode: r.mode,
            playlist: r.playlist,
            theme: r.theme,
          )
        else
          other,
    ];
    _commit(next);
  }

  void _delete(Skin skin, ContextRule r) {
    _commit([
      for (final other in state.contextRules.rules)
        if (other.id != r.id) other,
    ]);
  }

  Future<void> _add(BuildContext context, Skin skin) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: skin.background,
      isScrollControlled: true,
      builder: (ctx) => _NewRuleSheet(
        skin: skin,
        existingIds: {
          for (final r in state.contextRules.rules) r.id,
        },
        playlists: state.playlists.all,
        onCreate: (rule) {
          _commit([...state.contextRules.rules, rule]);
        },
      ),
    );
  }
}

class _NewRuleSheet extends StatefulWidget {
  const _NewRuleSheet({
    required this.skin,
    required this.existingIds,
    required this.playlists,
    required this.onCreate,
  });

  final Skin skin;
  final Set<String> existingIds;
  final List<Playlist> playlists;
  final void Function(ContextRule) onCreate;

  @override
  State<_NewRuleSheet> createState() => _NewRuleSheetState();
}

class _NewRuleSheetState extends State<_NewRuleSheet> {
  ContextBand? _band;
  ManualMode? _mode;
  WeatherWant _weather = WeatherWant.any;
  String? _playlistId;
  String? _theme;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final canSave = _band != null || _mode != null ||
        _weather == WeatherWant.rain || _playlistId != null || _theme != null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NEW RULE',
              style: TextStyle(
                fontSize: LayoutSpec.fontTitle,
                fontWeight: FontWeight.w900,
                color: skin.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(

              'Every condition you pick has to hold at once. Pick none and the '
              'rule matches every moment — put those at the bottom.',
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            _label(skin, 'WHEN THE TIME BAND IS'),
            _chips<ContextBand>(
              skin,
              ContextBand.values,
              _band,
              (v) => setState(() => _band = v),
              (b) => b == ContextBand.darkHour ? 'dark hour' : b.name,
            ),

            const SizedBox(height: 16),
            _label(skin, 'AND THE MANUAL CONTEXT IS'),
            _chips<ManualMode>(
              skin,
              ManualMode.values,
              _mode,
              (v) => setState(() => _mode = v),
              (m) => m.label,
            ),

            const SizedBox(height: 16),
            _label(skin, 'AND THE WEATHER'),
            _chips<WeatherWant>(
              skin,
              const [WeatherWant.any, WeatherWant.rain],
              _weather,

              (v) => setState(() => _weather = v ?? WeatherWant.any),
              (w) => w == WeatherWant.rain ? 'raining' : 'any',
            ),

            const SizedBox(height: 16),
            _label(skin, 'PLAY THIS PLAYLIST'),
            _playlistChips(skin),

            const SizedBox(height: 16),
            _label(skin, 'AND USE THIS THEME (OPTIONAL)'),
            _chips<String>(
              skin,
              const ['abyss', 'amber', 'crimson'],
              _theme,
              (v) => setState(() => _theme = v),
              (t) => t.toUpperCase(),
            ),

            const SizedBox(height: 22),
            Pressable(
              child: ElevatedButton(
                onPressed: canSave ? _create : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: skin.accent,
                  foregroundColor: skin.onAccent,
                  minimumSize: const Size.fromHeight(LayoutSpec.tapTarget),
                ),
                child: const Text('CREATE THE RULE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(Skin skin, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: LayoutSpec.fontLabel,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: skin.textSecondary,
          ),
        ),
      );

  Widget _chips<T>(
    Skin skin,
    List<T> values,
    T? selected,
    void Function(T?) onPick,
    String Function(T) label,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            _chip(skin, label(v), v == selected, () {
              onPick(v == selected ? null : v);
            }),
        ],
      );

  Widget _playlistChips(Skin skin) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in widget.playlists)
            _chip(skin, p.name, _playlistId == p.id, () {
              setState(() => _playlistId = _playlistId == p.id ? null : p.id);
            }),
        ],
      );

  Widget _chip(
    Skin skin,
    String label,
    bool selected,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? skin.accentAt(0.2) : Colors.transparent,
            border: Border.all(
              color: selected
                  ? skin.accent
                  : skin.secondary(0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: LayoutSpec.fontSmall,
              fontWeight: FontWeight.w700,
              color: selected ? skin.accent : skin.textPrimary,
            ),
          ),
        ),
      );

  void _create() {
    final parts = <String>[
      if (_mode != null) _mode!.name,
      if (_band != null) _band!.name,
      if (_weather == WeatherWant.rain) 'rain',
      if (_playlistId != null) 'mix',
    ];
    if (parts.isEmpty) parts.add('always');

    var id = parts
        .join('-')
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    var candidate = id;
    var n = 2;
    while (widget.existingIds.contains(candidate)) {
      candidate = '$id-$n';
      n++;
    }

    widget.onCreate(ContextRule(
      id: candidate,
      priority: 90,
      band: _band,
      weather: _weather,
      mode: _mode,
      playlist: _playlistId,
      theme: _theme == null
          ? null
          : SkinId.values.where((s) => s.name == _theme).firstOrNull,
    ));
    Navigator.of(context).pop();
  }
}
