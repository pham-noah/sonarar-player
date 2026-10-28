library;

import 'package:flutter/material.dart';

import '../widgets/pressable.dart';
import '../widgets/devices.dart';
import '../widgets/framed_art.dart';

import '../context/weather_codes.dart';
import '../core/app_state.dart';
import '../core/prefs.dart';
import '../art/skin_art.dart' show kAllArtSets;
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/theme_preset.dart';
import '../widgets/stagger_in.dart';

import '../widgets/spectrum.dart' show SpectrumShape;
import '../theme/slab.dart';
import 'art_framing_panel.dart';

enum _Part { palette, art, words }

enum SettingsSection {
  customization,

  behaviour,

  all,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    this.showTitle = true,
    this.section = SettingsSection.all,
    super.key,
    required this.state,
    this.onOpenDiagnostics,
    this.onSavePreset,
    this.onDeletePreset,
    this.onContextsChanged,
    this.prefs,
    this.onPrefsChanged,
    this.weather = WeatherCondition.unknown,
  });

  final AppState state;

  final bool showTitle;

  final SettingsSection section;

  bool get _showCustomization =>
      section == SettingsSection.customization || section == SettingsSection.all;

  bool get _showBehaviour =>
      section == SettingsSection.behaviour || section == SettingsSection.all;

  final AppPrefs? prefs;
  final ValueChanged<AppPrefs>? onPrefsChanged;

  final WeatherCondition weather;

  final VoidCallback? onContextsChanged;

  final VoidCallback? onOpenDiagnostics;

  final ValueChanged<String>? onSavePreset;

  final ValueChanged<ThemePreset>? onDeletePreset;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get state => widget.state;
  Skin get skin => state.uiSkin;
  WeatherCondition get weather => widget.weather;
  AppPrefs? get prefs => widget.prefs;
  ValueChanged<AppPrefs>? get onPrefsChanged => widget.onPrefsChanged;
  VoidCallback? get onContextsChanged => widget.onContextsChanged;
  VoidCallback? get onOpenDiagnostics => widget.onOpenDiagnostics;
  ValueChanged<String>? get onSavePreset => widget.onSavePreset;
  ValueChanged<ThemePreset>? get onDeletePreset => widget.onDeletePreset;

  @override
  Widget build(BuildContext context) {
    final skin = this.skin;

    return ColoredBox(
      color: skin.background,

      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
          ..._withoutLeadingGap([
            if (widget.showTitle) ...[
              ScreenTitle(skin: skin, text: 'SETTINGS'),
              const SizedBox(height: LayoutSpec.gapM),
            ],

            if (widget._showCustomization) ...[
            const SizedBox(height: 26),
            StaggerIn(
              index: 3,
              style: StaggerStyle.stamp,
              child: SectionBand(skin: skin, label: 'LAYOUT'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (i, option) in LayoutKind.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _layoutTile(skin, option)),
                ],
              ],
            ),
            ],

            if (widget._showCustomization) ...[
            const SizedBox(height: 16),
            StaggerIn(
              index: 3,
              style: StaggerStyle.stamp,
              child: SectionBand(skin: skin, label: 'SONG LIST'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _viewTile(
                    skin,
                    'GRID',
                    Icons.grid_view_rounded,

                    active: prefs?.libraryIsGrid ??
                        state.arrangement.libraryIsGrid,
                    onTap: onPrefsChanged == null
                        ? null
                        : () => onPrefsChanged!(
                            prefs!.copyWith(libraryIsGrid: true)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _viewTile(
                    skin,
                    'LIST',
                    Icons.view_list_rounded,
                    active: !(prefs?.libraryIsGrid ??
                        state.arrangement.libraryIsGrid),
                    onTap: onPrefsChanged == null
                        ? null
                        : () => onPrefsChanged!(
                            prefs!.copyWith(libraryIsGrid: false)),
                  ),
                ),
              ],
            ),
            ],

            if (widget._showCustomization) ...[
            const SizedBox(height: 16),
            StaggerIn(
              index: 2,
              style: StaggerStyle.stamp,
              child: SectionBand(skin: skin, label: 'THEME'),
            ),
            if (state.layoutId == LayoutKind.persona) ...[
            for (final preset in state.allPresets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _presetRow(preset),
              ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(width: 74, child: _autoTile(skin)),
                SizedBox(
                    width: 74,
                    child: _pickTile('PALETTE', Icons.palette_outlined,
                        () => _editPart(_Part.palette))),
                SizedBox(
                    width: 74,
                    child: _pickTile('ART', Icons.image_outlined,
                        () => _editPart(_Part.art))),
                SizedBox(
                    width: 74,
                    child: _pickTile('WORDS', Icons.translate_rounded,
                        () => _editPart(_Part.words))),
                SizedBox(
                    width: 74,
                    child: _pickTile('SAVE', Icons.bookmark_add_outlined,
                        _savePreset)),
              ],
            ),
            ] else
              for (final (i, named) in (switch (state.layoutId) {
                LayoutKind.solid => kSolidPalettes,
                LayoutKind.glass => kGlassPalettes,
                LayoutKind.persona => const <NamedPalette>[],
              }).indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Slab(
                    skin: skin,
                    active: state.paletteIndex == i,
                    onTap: () => onPrefsChanged!(prefs!.copyWith(paletteIndex: i)),
                    padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
                    child: Row(
                      children: [

                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: named.palette.surface,
                            border: Border.all(color: named.palette.accent, width: 2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            named.name,
                            style: TextStyle(
                              fontSize: LayoutSpec.fontBase,
                              fontWeight: FontWeight.w700,
                              color: state.paletteIndex == i
                                  ? skin.onAccent
                                  : skin.textPrimary,
                            ),
                          ),
                        ),
                        if (state.paletteIndex == i)
                          Icon(Icons.check_rounded, color: skin.onAccent),
                      ],
                    ),
                  ),
                ),

            ],
            const SizedBox(height: 16),
            if (widget._showCustomization) ...[
            const SizedBox(height: 16),
            StaggerIn(
              index: 4,
              style: StaggerStyle.stamp,
              child: SectionBand(skin: skin, label: 'ART'),
            ),
            const SizedBox(height: 6),
            _artSetRow(skin),

            if (state.hasArt) ...[
              const SizedBox(height: 12),
              _artStrip(skin),
              const SizedBox(height: 14),

              if (state.art != null)
                ArtFramingPanel(
                  skin: skin,
                  piece: state.art!,
                  focus: state.artFocus,
                  customised: state.hasCustomFocus(state.art!),
                  onFocus: (f) {
                    state.setArtFocus(f);
                    onContextsChanged?.call();
                  },
                  onReset: () {
                    state.resetArtFocus();
                    onContextsChanged?.call();
                  },
                ),
            ],

            ],

            if (widget._showBehaviour && prefs != null && onPrefsChanged != null) ...[
              const SizedBox(height: 26),
              StaggerIn(
                index: 3,
                style: StaggerStyle.stamp,
                child: SectionBand(skin: skin, label: 'BEHAVIOUR'),
              ),
              _toggle(skin, 'RESUME ON OPEN', prefs!.resumeOnLaunch,
                  icon: Icons.play_circle_outline_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(resumeOnLaunch: v))),
              _stepper(
                skin,
                'FADE IN',
                icon: Icons.multitrack_audio_rounded,
                prefs!.crossfadeSeconds == 0 ? 'OFF' : '${prefs!.crossfadeSeconds}s',
                onLess: prefs!.crossfadeSeconds <= 0
                    ? null
                    : () => onPrefsChanged!(
                        prefs!.copyWith(crossfadeSeconds: prefs!.crossfadeSeconds - 1)),
                onMore: prefs!.crossfadeSeconds >= 12
                    ? null
                    : () => onPrefsChanged!(
                        prefs!.copyWith(crossfadeSeconds: prefs!.crossfadeSeconds + 1)),
              ),
              _stepper(
                skin,
                'SLEEP LENGTH',
                icon: Icons.bedtime_rounded,
                '${prefs!.sleepTimerMinutes} min',
                onLess: () => onPrefsChanged!(
                    prefs!.copyWith(sleepTimerMinutes: prefs!.sleepTimerMinutes - 5)),
                onMore: () => onPrefsChanged!(
                    prefs!.copyWith(sleepTimerMinutes: prefs!.sleepTimerMinutes + 5)),
              ),

              if (prefs!.allowNetwork)
                _stepper(
                  skin,
                  'WEATHER EVERY',
                  icon: Icons.cloud_sync_rounded,
                  '${prefs!.weatherRefreshMinutes}m',
                  onLess: () => onPrefsChanged!(
                      prefs!.copyWith(
                          weatherRefreshMinutes: prefs!.weatherRefreshMinutes - 5)),
                  onMore: () => onPrefsChanged!(
                      prefs!.copyWith(
                          weatherRefreshMinutes: prefs!.weatherRefreshMinutes + 5)),
                ),
              if (prefs!.allowNetwork)
                _toggle(skin, 'OFFICIAL ONLY', prefs!.officialOnly,
                    icon: Icons.verified_rounded,
                    (v) => onPrefsChanged!(prefs!.copyWith(officialOnly: v))),
              _toggle(skin, 'OFFLINE', prefs!.allowNetwork,
                  icon: Icons.wifi_off_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(allowNetwork: v))),

              _toggle(skin, 'TIME OF DAY', prefs!.contextClock,
                  icon: Icons.schedule_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(contextClock: v))),
              if (prefs!.allowNetwork)
                _toggle(skin, 'WEATHER', prefs!.contextWeather,
                    icon: Icons.wb_cloudy_rounded,
                    (v) => onPrefsChanged!(prefs!.copyWith(contextWeather: v))),
              _toggle(skin, 'DYNAMIC MIX', prefs!.contextMix,
                  icon: Icons.shuffle_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(contextMix: v))),
              if (prefs!.allowNetwork)
                _toggle(skin, 'PLACES', prefs!.placesEnabled,
                    icon: Icons.place_rounded,
                    (v) => onPrefsChanged!(prefs!.copyWith(placesEnabled: v))),
              _toggle(skin, 'WEATHER VARIANTS', prefs!.weatherVariants,
                  icon: Icons.swap_horiz_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(weatherVariants: v))),
              _toggle(skin, 'AUTO THEME', prefs!.autoSkin,
                  icon: Icons.palette_outlined,
                  (v) => onPrefsChanged!(prefs!.copyWith(autoSkin: v))),
              _toggle(skin, 'LEARN FROM SKIPS', prefs!.learnFromSkips,
                  icon: Icons.psychology_alt_outlined,
                  (v) => onPrefsChanged!(prefs!.copyWith(learnFromSkips: v))),
              _toggle(skin, 'PLAY HISTORY', prefs!.recordHistory,
                  icon: Icons.timeline_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(recordHistory: v))),
              _toggle(skin, 'BONDS', prefs!.personaLayer,
                  icon: Icons.diversity_1_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(personaLayer: v))),

              _toggle(skin, 'TAB ANIMATION', prefs!.tabAnimation,
                  icon: Icons.movie_filter_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(tabAnimation: v))),

              _toggle(skin, 'FPS COUNTER', prefs!.showFps,
                  icon: Icons.speed_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(showFps: v))),
              _toggle(skin, 'SPECTRUM', prefs!.showVisualiser,
                  (v) => onPrefsChanged?.call(prefs!.copyWith(showVisualiser: v)),
                  icon: Icons.graphic_eq_rounded),
              if (prefs!.showVisualiser)
                _slider(
                  skin,
                  'SMOOTHNESS',
                  icon: Icons.waves_rounded,
                  value: (prefs!.spectrumSmoothness ??
                          AppPrefs.defaultSmoothnessPercent)
                      .toDouble(),
                  min: 0,
                  max: 100,

                  shown: _smoothnessLabel(
                      prefs!.spectrumSmoothness ??
                          AppPrefs.defaultSmoothnessPercent),
                  onChanged: (v) => onPrefsChanged!(
                      prefs!.copyWith(spectrumSmoothness: v.round())),
                ),
              if (prefs!.showVisualiser)
                _slider(
                  skin,
                  'SCALE',
                  icon: Icons.height_rounded,
                  value: prefs!.spectrumScalePercent.toDouble(),

                  min: 40,
                  max: 220,
                  shown: '${prefs!.spectrumScalePercent}%',
                  onChanged: (v) =>
                      onPrefsChanged!(prefs!.copyWith(spectrumScale: v.round())),
                ),

              if (prefs!.showVisualiser) ...[
                const SizedBox(height: 2),
                _row(
                  skin,
                  label: 'SHAPE',
                  icon: Icons.category_rounded,
                  trailing: const SizedBox.shrink(),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in SpectrumShape.values)
                      SizedBox(
                        width: 96,
                        child: _pickTile(
                          option.label,
                          Icons.square_rounded,
                          () => onPrefsChanged!(
                              prefs!.copyWith(spectrumShape: option.name)),
                          selected: prefs!.spectrumShapeName == option.name,
                        ),
                      ),
                  ],
                ),
              ],
              _toggle(skin, 'ROMAJI', prefs!.showRomaji,
                  icon: Icons.translate_rounded,
                  (v) => onPrefsChanged?.call(prefs!.copyWith(showRomaji: v))),
              _toggle(skin, 'CHARACTER FOLLOWS TRACK', prefs!.cycleCharacterArt,
                  icon: Icons.face_retouching_natural_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(cycleCharacterArt: v))),

              if (prefs!.contextMix)
                _toggle(skin, 'DYNAMIC BY DEFAULT', prefs!.dynamicByDefault,
                    icon: Icons.auto_awesome_motion_rounded,
                    (v) => onPrefsChanged!(prefs!.copyWith(dynamicByDefault: v))),
              _toggle(skin, 'KEEP PLAYING WHEN QUEUE ENDS', prefs!.refillWhenQueueEnds,
                  icon: Icons.autorenew_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(refillWhenQueueEnds: v))),
            ],
            if (widget._showBehaviour && onOpenDiagnostics != null) ...[
              StaggerIn(
                index: 4,
                style: StaggerStyle.stamp,
                child: SectionBand(skin: skin, label: 'IF SOMETHING IS WRONG'),
              ),
              _row(
                skin,
                label: 'DIAGNOSTICS',
                icon: Icons.receipt_long_rounded,

                trailing: Icon(Icons.chevron_right_rounded,
                    size: 20, color: skin.textSecondary.withValues(alpha: 0.6)),
                onTap: onOpenDiagnostics,
              ),
              const SizedBox(height: 16),
            ],
          ]),
          ],
        ),
      ),
    );
  }

  List<Widget> _withoutLeadingGap(List<Widget> children) {
    final start = children.indexWhere(
      (w) => !(w is SizedBox && (w.height ?? 0) > 0),
    );
    if (start < 0) return children;
    return children.sublist(start);
  }

  Widget _toggle(
    Skin skin,
    String label,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
  }) =>
      _row(
        skin,
        label: label,
        icon: icon,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: skin.accent,
          activeTrackColor: skin.accent.withValues(alpha: 0.35),
        ),
        onTap: () => onChanged(!value),
      );

  Widget _slider(
    Skin skin,
    String label, {
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String shown,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
          decoration: BoxDecoration(
            color: skin.panel,
            border: Border(
              left: BorderSide(color: skin.accent.withValues(alpha: 0.7), width: 3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, size: 17, color: skin.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: skin.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Slab(
                    skin: skin,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: Text(
                      shown,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: skin.onAccent,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 30,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: skin.accent,
                    inactiveTrackColor: skin.accent.withValues(alpha: 0.22),
                    thumbColor: skin.accent,
                    overlayColor: skin.accent.withValues(alpha: 0.14),

                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _stepper(
    Skin skin,
    String label,
    String value, {
    VoidCallback? onLess,
    VoidCallback? onMore,
    IconData? icon,
  }) =>
      _row(
        skin,
        label: label,
        icon: icon,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepButton(skin, Icons.remove_rounded, onLess),

            SizedBox(
              width: 104,
              child: Center(
                child: Stamp(
                  skin: skin,
                  label: value,
                  accent: false,
                ),
              ),
            ),
            _stepButton(skin, Icons.add_rounded, onMore),
          ],
        ),
      );

  Widget _stepButton(Skin skin, IconData icon, VoidCallback? onTap) {
    final off = onTap == null;
    return Pressable(
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: off
                  ? skin.textSecondary.withValues(alpha: 0.25)
                  : skin.accent.withValues(alpha: 0.6),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: off
                ? skin.textSecondary.withValues(alpha: 0.3)
                : skin.accent,
          ),
        ),
      ),
    );
  }

  Widget _row(
    Skin skin, {
    required String label,
    required Widget trailing,

    IconData? icon,
    VoidCallback? onTap,
  }) =>
      Padding(

        padding: const EdgeInsets.only(bottom: 6),
        child: Pressable(
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                color: skin.panel,
                border: Border(

                  left: BorderSide(color: skin.accent.withValues(alpha: 0.7), width: 3),
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: skin.accent),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: skin.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      );

  Widget _presetRow(ThemePreset preset) {
    final palette = skinFor(preset.skinId);
    final active = state.preset?.id == preset.id;
    final borrowed = <String>[
      if (preset.artSkinId != null && preset.artSkinId != preset.skinId)
        'art: ${skinFor(preset.effectiveArtSkin).displayName}',
      if (preset.languageSkinId != null &&
          preset.languageSkinId != preset.skinId)
        'words: ${skinFor(preset.effectiveLanguageSkin).displayName}',
    ];

    return Pressable(
      child: InkWell(
        onTap: () {
          state.applyPreset(preset);
          onPrefsChanged?.call(prefs!.copyWith(
            activePresetId: preset.id,
            layoutId: state.layoutId.name,
            paletteIndex: state.paletteIndex,
          ));
          onContextsChanged?.call();
          setState(() {});
        },

        onLongPress: preset.builtIn ? null : () => _presetActions(preset),
        child: Container(

          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: active ? palette.background : skin.panel,
            border: Border(
              left: BorderSide(
                color: active ? palette.accent : palette.accent.withValues(alpha: 0.55),
                width: active ? 5 : 3,
              ),
            ),
          ),
          child: Row(
            children: [

              Container(width: 16, height: 16, color: palette.accent),
              const SizedBox(width: 3),
              Container(width: 16, height: 16, color: palette.accentDeep),
              const SizedBox(width: 3),
              Container(width: 16, height: 16, color: palette.panel),
              const SizedBox(width: 3),
              Container(
                width: 16,
                height: 16,
                color: palette.background,
                child: Center(
                  child: Container(width: 6, height: 6, color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        preset.name,
                        maxLines: 1,

                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                          color: skin.textPrimary,
                        ),
                      ),
                    ),
                    if (borrowed.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          borrowed.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: skin.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (active)
                Icon(Icons.check_circle_rounded, size: 18, color: skin.accent),
              if (preset.builtIn)
                Icon(Icons.lock_outline_rounded, size: 14, color: skin.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layoutTile(Skin skin, LayoutKind option) {
    final active = state.layoutId == option;
    return Pressable(
      child: InkWell(
        onTap: () => onPrefsChanged!(prefs!.copyWith(layoutId: option.name)),
        child: Slab(
          presentation: PresentationScope.of(context, fallback: skin),
          skin: skin,
          active: active,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          child: Column(
            children: [
              Icon(
                switch (option) {
                  LayoutKind.persona => Icons.auto_awesome_rounded,
                  LayoutKind.solid => Icons.crop_square_rounded,
                  LayoutKind.glass => Icons.blur_on_rounded,
                },
                size: 19,
                color: active ? skin.onAccent : skin.accent,
              ),
              const SizedBox(height: 5),

              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  switch (option) {
                    LayoutKind.persona => 'PERSONA',
                    LayoutKind.solid => 'SOLID',
                    LayoutKind.glass => 'GLASS',
                  },
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: active ? skin.onAccent : skin.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewTile(
    Skin skin,
    String label,
    IconData icon, {
    required bool active,
    VoidCallback? onTap,
  }) =>
      Pressable(
        child: InkWell(
          onTap: onTap,
          child: Slab(
            presentation: PresentationScope.of(context, fallback: skin),
            skin: skin,
            active: active,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
            child: Column(
              children: [
                Icon(icon,
                    size: 20, color: active ? skin.onAccent : skin.accent),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                      color: active ? skin.onAccent : skin.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _artSetRow(Skin skin) {
    final current = state.artSkinOverride;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 88,
          child: _pickTile(
            'FOLLOW',
            Icons.link_rounded,
            () {
              state.setArtSkin(null);
              onContextsChanged?.call();
            },
            selected: current == null,
          ),
        ),
        for (final set in kAllArtSets)
          if (set.hasArt)
            SizedBox(
              width: 88,
              child: _pickTile(
                skinFor(set.skinId).displayName.toUpperCase(),
                Icons.image_outlined,
                () {
                  state.setArtSkin(set.skinId);
                  onPrefsChanged?.call(prefs!.copyWith(artSkinId: set.skinId.name));
                  onContextsChanged?.call();
                  setState(() {});
                },
                selected: current == set.skinId,
              ),
            ),
      ],
    );
  }

  Widget _pickTile(String label, IconData icon, VoidCallback onTap, {bool? selected}) {
    final active = selected ?? false;
    return Pressable(
      child: InkWell(
        onTap: onTap,
        child: Slab(
        presentation: PresentationScope.of(context, fallback: skin),
          skin: skin,
          active: active,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          child: Column(
            children: [
              Icon(icon,
                  size: 19, color: active ? skin.onAccent : skin.accent),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: active ? skin.onAccent : skin.textSecondary,
                  ),
                ),
              ),

              if (selected == true) ...[
                const SizedBox(height: 3),
                Icon(Icons.check_rounded, size: 12, color: skin.onAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editPart(_Part part) async {
    final current = switch (part) {
      _Part.palette => state.skin.id,
      _Part.art => state.artSkinOverride ?? state.skin.id,
      _Part.words => state.languageSkin.id,
    };

    var follow = false;
    final chosen = await showModalBottomSheet<SkinId?>(
      context: context,
      backgroundColor: skin.background,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              switch (part) {
                _Part.palette => 'PALETTE',
                _Part.art => 'ART',
                _Part.words => 'WORDS',
              },
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w900,
                color: skin.accent,
              ),
            ),
            const SizedBox(height: 6),
            Text(

              switch (part) {
                _Part.palette =>
                  'The colours. The other two follow it unless you set them.',
                _Part.art =>
                  'Which artwork is drawn behind the player — free of the palette.',
                _Part.words =>
                  'Persona vocabulary or plain wording — free of the palette.',
              },
              style: TextStyle(
                  fontSize: 14, color: skin.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 8),

            if (part != _Part.palette)
              ListTile(
                leading: Icon(Icons.link_rounded, color: skin.accent),
                title: Text('Follow the palette',
                    style: TextStyle(
                        color: skin.textPrimary, fontWeight: FontWeight.w700)),
                subtitle: Text(skinFor(state.skin.id).displayName,
                    style: TextStyle(color: skin.textSecondary)),
                onTap: () {
                  follow = true;
                  Navigator.of(ctx).pop(null);
                },
              ),
            for (final option in kAllSkins)
              ListTile(
                leading: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: option.background,
                    border: Border.all(
                      color:
                          current == option.id ? option.accent : option.panel,
                      width: current == option.id ? 3 : 1,
                    ),
                  ),
                ),
                title: Text(option.displayName,
                    style: TextStyle(color: skin.textPrimary)),
                trailing: current == option.id
                    ? Icon(Icons.check_rounded, color: skin.accent)
                    : null,
                onTap: () => Navigator.of(ctx).pop(option.id),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (chosen == null && !follow) return;

    switch (part) {
      case _Part.palette:
        if (chosen == null) return;
        state.applyPreset(ThemePreset(
          id: 'edit_${chosen.name}',
          name: skinFor(chosen).displayName,
          skinId: chosen,
          artSkinId: state.artSkinOverride,
          languageSkinId:
              state.languageSkin.id == chosen ? null : state.languageSkin.id,
        ));

        onPrefsChanged?.call(prefs!.copyWith(
          layoutId: state.layoutId.name,
          paletteIndex: state.paletteIndex,
          skinId: state.skin.id.name,
          clearPreset: true,
        ));
      case _Part.art:
        state.setArtSkin(chosen);
        onPrefsChanged?.call(prefs!
            .copyWith(artSkinId: chosen?.name, clearArtSkin: chosen == null));
      case _Part.words:
        state.setLanguageSkin(chosen);
        onPrefsChanged?.call(prefs!.copyWith(
            languageSkinId: chosen?.name, clearLanguageSkin: chosen == null));
    }
    onContextsChanged?.call();
    setState(() {});
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController(text: _suggestedPresetName());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: skin.background,
        title: Text('Save theme',
            style: TextStyle(color: skin.textPrimary, fontSize: 19)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: skin.textPrimary, fontSize: 17),
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: TextStyle(color: skin.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('SAVE', style: TextStyle(color: skin.accent)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    onSavePreset?.call(name.trim());
  }

  static String _smoothnessLabel(int percent) {
    if (percent <= 10) return 'GLIDE';
    if (percent <= 30) return 'SMOOTH';
    if (percent <= 55) return 'BALANCED';
    if (percent <= 80) return 'BRISK';
    return 'SNAP';
  }

  String _suggestedPresetName() {
    final parts = <String>[skinFor(state.skin.id).displayName];
    final art = state.artSkinOverride;
    if (art != null && art != state.skin.id) {
      parts.add('+${skinFor(art).displayName} art');
    }
    if (state.languageSkin.id != state.skin.id) {
      parts.add('+${state.languageSkin.displayName} words');
    }
    return parts.join(' ');
  }

  Future<void> _presetActions(ThemePreset preset) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: skin.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Delete "${preset.name}"',
                  style: TextStyle(color: skin.accent)),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(

                'The built-in themes can be edited by saving a copy, but not deleted.',
                style: TextStyle(fontSize: 13, color: skin.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
    if (go == true) onDeletePreset?.call(preset);
  }

  Widget _autoTile(Skin skin) {
    final auto = !state.preference.isManual;
    return Pressable(
      child: InkWell(
        onTap: () {
          state.followContextAgain();
          onContextsChanged?.call();
        },
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: auto ? skin.accent.withValues(alpha: 0.16) : Colors.transparent,
            border: Border.all(
              color:
                  auto ? skin.accent : skin.textSecondary.withValues(alpha: 0.35),
              width: auto ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 20, color: auto ? skin.accent : skin.textSecondary),
              const SizedBox(height: 7),
              Icon(
                auto ? Icons.check_rounded : Icons.remove_rounded,
                size: auto ? 16 : 12,
                color: auto ? skin.accent : skin.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _artStrip(Skin skin) {
    final artSet = state.artSet;
    final shown = artSet.length > 8 ? 8 : artSet.length;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = i == state.artIndex;
          final piece = artSet.pieces[i];
          return Pressable(
            child: InkWell(
              onTap: () {
                state.selectArt(i);
                onContextsChanged?.call();
              },
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  color: skin.panel,
                  border: Border.all(
                    color: selected
                        ? skin.accent
                        : skin.textSecondary.withValues(alpha: 0.3),
                    width: selected ? 3 : 1,
                  ),
                ),

                child: FramedArt(
                  assetPath: piece.assetPath,
                  aspect: piece.aspect,
                  focus: state.focusForPiece(piece),
                  cacheWidth: 180,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
