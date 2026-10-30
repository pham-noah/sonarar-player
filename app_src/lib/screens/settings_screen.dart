library;

import 'package:flutter/material.dart';

import '../widgets/pressable.dart';
import '../widgets/devices.dart';
import '../widgets/kit.dart';
import '../backup/backup_section.dart';

import '../context/weather_codes.dart';
import '../core/app_state.dart';
import '../core/links.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/theme_preset.dart';
import '../widgets/stagger_in.dart';

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
    this.musicRoot,
    this.onOpenMusicFolder,
    this.stateDirectory,
    this.downloadDirectory,
    this.appVersion,
  });

  final AppState state;

  /// The folder the library is read from, and the door to change it.
  final String? musicRoot;
  final VoidCallback? onOpenMusicFolder;

  /// Where the `.state` folder lives and where a backup is written. Backup
  /// hides itself when either is unknown, so a test or a preview that builds
  /// this page without a shell still renders.
  final String? stateDirectory;
  final String? downloadDirectory;
  final String? appVersion;

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

/// Pages of Settings. The strip on screen is the same one Personalize wears,
/// so the two screens read as one place with different rooms.
enum SettingsTab { look, playback, library, system }

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsTab _tab = SettingsTab.playback;

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
            KitTabs<SettingsTab>(
              skin: skin,
              labels: const {
                SettingsTab.look: 'LOOK',
                SettingsTab.playback: 'PLAYBACK',
                SettingsTab.library: 'LIBRARY',
                SettingsTab.system: 'SYSTEM',
              },
              selected: _tab,
              onSelected: (t) => setState(() => _tab = t),
              keyBuilder: (t) => Key('settings-tab-${t.name}'),
            ),
            const SizedBox(height: 14),

            
            
            if (_tab == SettingsTab.look &&
                widget._showCustomization &&
                widget.onOpenPersonalize != null) ...[
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
              if (_tab == SettingsTab.playback) ...[
              const SizedBox(height: 2),
              StaggerIn(
                index: 3,
                style: StaggerStyle.stamp,
                child: SectionBand(skin: skin, label: 'PLAYBACK'),
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
              SectionBand(skin: skin, label: 'CONTEXT'),
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
              SectionBand(skin: skin, label: 'LISTENING MEMORY'),
              _toggle(skin, 'LEARN FROM SKIPS', prefs!.learnFromSkips,
                  icon: Icons.psychology_alt_outlined,
                  (v) => onPrefsChanged!(prefs!.copyWith(learnFromSkips: v))),
              _toggle(skin, 'PLAY HISTORY', prefs!.recordHistory,
                  icon: Icons.timeline_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(recordHistory: v))),
              _toggle(skin, 'BONDS', prefs!.personaLayer,
                  icon: Icons.diversity_1_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(personaLayer: v))),

              ],
              if (_tab == SettingsTab.library &&
                  widget.onOpenMusicFolder != null) ...[
                SectionBand(skin: skin, label: 'LIBRARY'),
                KitRow(
                  skin: skin,
                  label: 'MUSIC FOLDER',
                  icon: Icons.folder_rounded,
                  onTap: widget.onOpenMusicFolder,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      widget.musicRoot ?? 'default',
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Text(
                    'A folder is a library when it holds library_manifest.json. '
                    'Your history, playlists and themes stay where they are, so '
                    'changing this never loses them.',
                    style: TextStyle(fontSize: 12, color: skin.textSecondary),
                  ),
                ),
              ],
              if (_tab == SettingsTab.system) ...[
              SectionBand(skin: skin, label: 'INTERFACE'),
              _toggle(skin, 'FPS COUNTER', prefs!.showFps,
                  icon: Icons.speed_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(showFps: v))),
              _toggle(skin, 'CHECK FOR UPDATES', prefs!.checkForUpdates,
                  icon: Icons.system_update_rounded,
                  (v) =>
                      onPrefsChanged!(prefs!.copyWith(checkForUpdates: v))),
              Text(
                'TAB ANIMATION and SPECTRUM live in Personalize now — they '
                'change how the app looks, so they sit with the look.',
                style: TextStyle(fontSize: 12, color: skin.textSecondary),
              ),
              _toggle(skin, 'ROMAJI', prefs!.showRomaji,
                  icon: Icons.translate_rounded,
                  (v) => onPrefsChanged?.call(prefs!.copyWith(showRomaji: v))),

              if (prefs!.contextMix)
                _toggle(skin, 'DYNAMIC BY DEFAULT', prefs!.dynamicByDefault,
                    icon: Icons.auto_awesome_motion_rounded,
                    (v) => onPrefsChanged!(prefs!.copyWith(dynamicByDefault: v))),
              _toggle(skin, 'KEEP PLAYING WHEN QUEUE ENDS', prefs!.refillWhenQueueEnds,
                  icon: Icons.autorenew_rounded,
                  (v) => onPrefsChanged!(prefs!.copyWith(refillWhenQueueEnds: v))),
              ],
            ],
            if (_tab == SettingsTab.system &&
                widget._showBehaviour &&
                onOpenDiagnostics != null) ...[
              StaggerIn(
                index: 4,
                style: StaggerStyle.stamp,
                child: SectionBand(skin: skin, label: 'IF SOMETHING IS WRONG'),
              ),
              KitRow(
                skin: skin,
                label: 'DIAGNOSTICS',
                icon: Icons.receipt_long_rounded,

                trailing: Icon(Icons.chevron_right_rounded,
                    size: 20, color: skin.textSecondary.withValues(alpha: 0.6)),
                onTap: onOpenDiagnostics,
              ),
              const SizedBox(height: 16),
            ],
            if (_tab == SettingsTab.system) ...[
              SectionBand(skin: skin, label: 'ABOUT'),
              // The name of the person who made this, and where the code lives.
              // Both are links: a credit you cannot follow is a stamp.
              _aboutRow(
                skin,
                label: 'MADE BY NOAH PHAM',
                icon: Icons.person_rounded,
                url: Links.author,
              ),
              _aboutRow(
                skin,
                label: 'SOURCE ON GITHUB',
                icon: Icons.code_rounded,
                url: Links.source,
              ),
              // Flutter collects every package's licence text; ours are in the
              // list above, so this page is the whole story in one place.
              KitRow(
                skin: skin,
                label: 'LICENSES',
                icon: Icons.article_rounded,
                trailing: Icon(Icons.chevron_right_rounded,
                    size: 20, color: skin.textSecondary.withValues(alpha: 0.6)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LicensePage(
                      applicationName: 'Sonarar',
                      applicationVersion: widget.appVersion,
                      applicationLegalese:
                          'GPL-3.0 — made by Noah Pham. Source and the exact '
                          'licence at github.com/pham-noah/sonarar-player',
                    ),
                  ),
                ),
              ),
              if (widget.appVersion != null && widget.appVersion!.isNotEmpty)
                KitRow(
                  skin: skin,
                  label: 'VERSION ${widget.appVersion}',
                  icon: Icons.info_outline_rounded,
                  trailing: const SizedBox.shrink(),
                ),
              const SizedBox(height: 16),
            ],
            if (_tab == SettingsTab.system &&
                widget._showBehaviour &&
                widget.stateDirectory != null &&
                widget.downloadDirectory != null)
              BackupSection(
                skin: skin,
                stateDirectory: widget.stateDirectory!,
                downloadDirectory: widget.downloadDirectory!,
                appVersion: widget.appVersion,
                row: ({required label, required icon, trailing, onTap}) =>
                    KitRow(skin: skin,
                        label: label,
                        icon: icon,
                        trailing: trailing ?? const SizedBox.shrink(),
                        onTap: onTap),
              ),
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
      KitRow(
        skin: skin,
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

  Widget _aboutRow(
    Skin skin, {
    required String label,
    required IconData icon,
    required String url,
  }) =>
      KitRow(
        skin: skin,
        label: label,
        icon: icon,
        trailing: Icon(Icons.open_in_new_rounded,
            size: 18, color: skin.textSecondary.withValues(alpha: 0.6)),
        onTap: () async {
          final opened = await openExternal(url);
          if (!opened && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('No app here can open $url')),
            );
          }
        },
      );

  // ignore: unused_element
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
      KitRow(
        skin: skin,
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

  // ignore: unused_element
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

  // ignore: unused_element
  static String _smoothnessLabel(int percent) {
    if (percent <= 10) return 'GLIDE';
    if (percent <= 30) return 'SMOOTH';
    if (percent <= 55) return 'BALANCED';
    if (percent <= 80) return 'BRISK';
    return 'SNAP';
  }

}

