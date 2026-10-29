library;

import 'package:flutter/material.dart';

import '../widgets/pressable.dart';
import '../widgets/devices.dart';

import '../context/weather_codes.dart';
import '../core/app_state.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/theme_preset.dart';
import '../widgets/stagger_in.dart';

import '../widgets/spectrum.dart' show SpectrumShape;
import '../theme/slab.dart';


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
    this.onOpenPersonalize,
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

  /// The one door to PERSONALIZE; Settings itself no longer edits appearance.
  final VoidCallback? onOpenPersonalize;

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

            
            
            if (widget._showCustomization && widget.onOpenPersonalize != null) ...[
              SectionBand(skin: skin, label: 'LOOK'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: widget.onOpenPersonalize,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    color: skin.panel,
                    child: Row(
                      children: [
                        Icon(Icons.wallpaper_rounded, color: skin.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PERSONALIZE',
                                  style: TextStyle(
                                    fontSize: LayoutSpec.fontFloor,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: skin.textPrimary,
                                  )),
                              Text('Layout, backdrop, accent, art, Home order',
                                  style: TextStyle(
                                      fontSize: LayoutSpec.fontFloor, color: skin.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: skin.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            
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
  }  static String _smoothnessLabel(int percent) {
    if (percent <= 10) return 'GLIDE';
    if (percent <= 30) return 'SMOOTH';
    if (percent <= 55) return 'BALANCED';
    if (percent <= 80) return 'BRISK';
    return 'SNAP';
  }

}

