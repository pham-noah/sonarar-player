library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../screens/reframe_screen.dart';
import '../theme/theme_preset.dart';
import '../widgets/kit.dart';
import '../widgets/spectrum.dart';
import '../art/art_bundle.dart';
import '../art/skin_art.dart';
import '../theme/backdrop_import.dart';
import '../theme/backdrop_layer.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import '../widgets/art_scrim.dart';
import '../widgets/devices.dart';
import '../widgets/framed_art.dart';

/// PERSONALIZE — the one place the app's look is decided.
///
/// Everything about the look lives here: the layout, the songs' shape, what is
/// painted behind each tab, where the accent comes from, and which Home
/// sections show in which order. Settings keeps behaviour only, so there is one
/// place to look instead of two that half-overlap.
/// The parts of the look, one at a time. Seven sections in a single scroll is
/// a scavenger hunt; five tabs is a page you can finish.
enum PersonalizeTab { themes, look, art, home }

class PersonalizeScreen extends StatefulWidget {
  const PersonalizeScreen({
    super.key,
    required this.state,
    this.onSaveTheme,
    this.greeting,
    this.prefs,
    this.onPrefsChanged,
    this.onApplyTheme,
    this.onDeleteTheme,
  });

  final AppState state;
  final void Function(String name)? onSaveTheme;

  /// Visual preferences (layout, song shape) that the screen edits directly.
  final AppPrefs? prefs;
  final ValueChanged<AppPrefs>? onPrefsChanged;

  final void Function(ThemePreset preset)? onApplyTheme;
  final void Function(ThemePreset preset)? onDeleteTheme;

  /// The greeting Home would show right now. The preview borrows it instead of
  /// inventing its own, so the sample matches the hour you are looking at it.
  final String? greeting;

  @override
  State<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends State<PersonalizeScreen> {
  PersonalizeTab _tab = PersonalizeTab.themes;
  late Personalization _p = widget.state.personalization;

  Skin get _skin => widget.state.uiSkin;
  Directory? get _root => widget.state.libraryRoot == null
      ? null
      : Directory(widget.state.libraryRoot!);

  void _apply(Personalization next) {
    setState(() => _p = next);
    widget.state.setPersonalization(next);
  }

  /// Which place the picture controls edit. Null is the default, the one every
  /// place uses unless it was given its own.
  SurfaceId? _surface;

  /// The one picture slot. A folder piece and a photo are the same thing here;
  /// what differs is whether it can walk to a next frame.
  void _setPic(String? artKey, {File? photo}) {
    _setBackdrop(
      _b.copyWith(
        artKey: artKey,
        clearArt: artKey == null,
        file: photo?.uri.pathSegments.last,
        clearFile: photo != null ? false : artKey != null,
      ),
    );
  }

  void _setBackdrop(BackdropSpec b) {
    if (_surface == null) {
      _apply(_p.copyWith(backdrop: b));
      return;
    }
    // A place picture has no framing of its own.
    _apply(
      _p.withSurface(
        _surface!,
        SurfaceLook(room: b.fromArt ? null : b.file, art: b.artKey),
      ),
    );
  }

  BackdropSpec get _b =>
      _surface == null ? _p.backdrop : _p.backdropFor(_surface!);

  @override
  Widget build(BuildContext context) {
    final skin = _skin;
    return Scaffold(
      backgroundColor: skin.background,
      body: SafeArea(
        child: Column(
          children: [
            // The strip and the way back stay put: switching parts should never
            // mean scrolling up to reach them first.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: skin.accent,
                        ),
                      ),
                      Text(
                        'PERSONALIZE',
                        style: TextStyle(
                          fontSize: LayoutSpec.fontBase,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          color: skin.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _tabs(skin),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                // Each tab keeps its own scroll position: switching parts should
                // not drop you halfway down a different page.
                key: PageStorageKey('personalize-${_tab.name}'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  // The mock home feed is not the picture.
                  if (_tab != PersonalizeTab.art) ...[
                    _preview(skin),
                    const SizedBox(height: 14),
                  ],

                  if (_tab == PersonalizeTab.look) ...[
                    SectionBand(skin: skin, label: 'LAYOUT'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final kind in const [
                          LayoutKind.glass,
                          LayoutKind.sonar,
                          LayoutKind.solid,
                        ])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _layoutTile(skin, kind),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SectionBand(skin: skin, label: 'SONG LIST'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _chip(
                          skin,
                          'GRID',
                          widget.prefs?.libraryIsGrid == true,
                          () => _setGrid(true),
                        ),
                        const SizedBox(width: 8),
                        _chip(
                          skin,
                          'LIST',
                          widget.prefs?.libraryIsGrid != true,
                          () => _setGrid(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SectionBand(skin: skin, label: 'MOTION'),
                    _toggleRow(
                      skin,
                      'TAB ANIMATION',
                      widget.prefs?.tabAnimation ?? true,
                      (v) => _prefs((p) => p.copyWith(tabAnimation: v)),
                    ),
                    _toggleRow(
                      skin,
                      'SPECTRUM',
                      widget.prefs?.showVisualiser ?? false,
                      (v) => _prefs((p) => p.copyWith(showVisualiser: v)),
                    ),
                    if (widget.prefs?.showVisualiser ?? false) ...[
                      _slider(
                        skin,
                        'SMOOTHNESS',
                        (widget.prefs?.spectrumSmoothness ?? 60).toDouble(),
                        0,
                        100,
                        (v) => _prefs(
                          (p) => p.copyWith(spectrumSmoothness: v.round()),
                        ),
                      ),
                      _slider(
                        skin,
                        'SCALE',
                        widget.prefs?.spectrumScalePercent.toDouble() ?? 100,
                        40,
                        220,
                        (v) =>
                            _prefs((p) => p.copyWith(spectrumScale: v.round())),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final shape in SpectrumShape.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _chip(
                                  skin,
                                  shape.label,
                                  widget.prefs?.spectrumShapeName == shape.name,
                                  () => _prefs(
                                    (p) =>
                                        p.copyWith(spectrumShape: shape.name),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    SectionBand(skin: skin, label: 'BASE'),
            SizedBox(
              height: 46,
              child: ListView.separated(
                key: const Key('base-row'),
                scrollDirection: Axis.horizontal,
                itemCount: _bases.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final onTheme = _p.base == null;
                    return GestureDetector(
                      key: const Key('base-theme'),
                      onTap: () => _apply(_p.copyWith(clearBase: true)),
                      child: Container(
                        width: 92,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: skin.panel,
                          border: Border.all(
                            color: onTheme ? skin.accent : skin.textSecondary,
                            width: onTheme ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          'THEME',
                          style: TextStyle(
                            color: onTheme ? skin.accent : skin.textSecondary,
                            fontSize: LayoutSpec.fontFloor - 5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    );
                  }
                  final colour = _bases[i - 1];
                  final picked = _p.base == colour.toARGB32();
                  return GestureDetector(
                    onTap: () =>
                        _apply(_p.copyWith(base: colour.toARGB32())),
                    child: Container(
                      width: 46,
                      color: colour,
                      child: picked
                          ? Icon(Icons.check,
                              size: 16,
                              color: colour.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SectionBand(skin: skin, label: 'ACCENT'),
                    _chip(
                      skin,
                      'FROM PHOTO',
                      _p.accent.source == AccentSource.image,
                      _accentFromPhoto,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        key: const Key('accent-wheel'),
                        scrollDirection: Axis.horizontal,
                        itemCount: _swatches.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final onTheme =
                                _p.accent.source == AccentSource.skin;
                            return GestureDetector(
                              key: const Key('accent-theme'),
                              onTap: () => _apply(
                                _p.copyWith(accent: const AccentSpec()),
                              ),
                              child: Container(
                                width: 92,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: skin.panel,
                                  border: Border.all(
                                    color: onTheme
                                        ? skin.accent
                                        : skin.textSecondary,
                                    width: onTheme ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  'THEME',
                                  style: TextStyle(
                                    color: onTheme
                                        ? skin.accent
                                        : skin.textSecondary,
                                    fontSize: LayoutSpec.fontFloor - 5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            );
                          }
                          final colour = _swatches[i - 1];
                          final picked =
                              _p.accent.source == AccentSource.manual &&
                              _p.accent.value == colour.toARGB32();
                          return GestureDetector(
                            onTap: () => _apply(
                              _p.copyWith(
                                accent: AccentSpec(
                                  source: AccentSource.manual,
                                  value: colour.toARGB32(),
                                ),
                              ),
                            ),
                            child: Container(
                              width: 38,
                              decoration: BoxDecoration(
                                color: colour,
                                border: Border.all(
                                  color: picked
                                      ? skin.textPrimary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_tab == PersonalizeTab.art) ...[
                    SectionBand(skin: skin, label: 'PICTURE FOR'),
                    _picturePreview(skin),
                    const SizedBox(height: 8),
                    const SizedBox(height: 6),
                    const SizedBox(height: 10),
                    _scopeStrip(skin),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            skin,
                            'NO PICTURE',
                            () => _setBackdrop(const BackdropSpec()),
                            quiet: !_b.isSet,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _button(
                            skin,
                            'ADD PICTURE',
                            _chooseImage,
                            quiet: _b.isSet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_b.isSet && _surface != null) ...[
                      const SizedBox(height: 10),
                    ],
                    if (_b.isSet) ...[
                      const SizedBox(height: 14),
                      _button(skin, 'REFRAME', _reframe, quiet: true),
                      const SizedBox(height: 6),
                      _slider(
                        skin,
                        'BLUR',
                        _b.blur,
                        0,
                        24,
                        (v) => _setBackdrop(_b.copyWith(blur: v)),
                      ),
                      _slider(
                        skin,
                        'DIM',
                        _b.dim,
                        0,
                        1,
                        (v) => _setBackdrop(_b.copyWith(dim: v)),
                      ),
                      _slider(
                        skin,
                        'ZOOM',
                        _b.scale,
                        1,
                        6,
                        (v) => _setBackdrop(_b.copyWith(scale: v)),
                      ),
                      _slider(
                        skin,
                        'ROTATION',
                        _b.rotationDeg,
                        -45,
                        45,
                        (v) => _setBackdrop(_b.copyWith(rotationDeg: v)),
                      ),
                      _toggle(
                        skin,
                        'TINT WITH ACCENT',
                        _b.tint,
                        (v) => _setBackdrop(_b.copyWith(tint: v)),
                      ),
                      _toggle(
                        skin,
                        'PLAYER USES THE COVER',
                        _b.coverOnPlayer,
                        (v) => _setBackdrop(_b.copyWith(coverOnPlayer: v)),
                      ),
                      if (_b.fromArt)
                        _toggle(
                          skin,
                          'FOLLOW TRACK',
                          _b.followTrack,
                          (v) => _setBackdrop(_b.copyWith(followTrack: v)),
                        ),
                      _slider(
                        skin,
                        'SATURATION',
                        _b.saturation,
                        0,
                        2,
                        (v) => _setBackdrop(_b.copyWith(saturation: v)),
                        shown: '${(_b.saturation * 100).round()}%',
                      ),
                      _slider(
                        skin,
                        'CONTRAST',
                        _b.contrast,
                        0.5,
                        2,
                        (v) => _setBackdrop(_b.copyWith(contrast: v)),
                        shown: '${(_b.contrast * 100).round()}%',
                      ),
                      _slider(
                        skin,
                        'VIGNETTE',
                        _b.vignette,
                        0,
                        1,
                        (v) => _setBackdrop(_b.copyWith(vignette: v)),
                      ),
                      _slider(
                        skin,
                        'GRAIN',
                        _b.grain,
                        0,
                        1,
                        (v) => _setBackdrop(_b.copyWith(grain: v)),
                      ),
                      _slider(
                        skin,
                        'BURN',
                        _b.burn,
                        0,
                        1,
                        (v) => _setBackdrop(_b.copyWith(burn: v)),
                      ),
                      if (_surface != null)
                        Text(
                          'Framing belongs to the picture, so these sliders move it '
                          'everywhere that picture is used.',
                          style: TextStyle(
                            color: skin.textSecondary,
                            fontSize: LayoutSpec.fontFloor - 4,
                            height: 1.4,
                          ),
                        ),
                    ],
                    if (!_b.isSet) ...[
                      Row(
                        children: [
                          _chip(
                            skin,
                            'SOLID',
                            _p.fill.isSet && !_p.fill.isGradient,
                            () => _setFill(
                              _p.fill.isSet
                                  ? _p.fill.copyWith(clearEnd: true)
                                  : const BackdropFill(start: 0xFF16121C),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            skin,
                            'GRADIENT',
                            _p.fill.isGradient,
                            () => _setFill(
                              BackdropFill(
                                start: _p.fill.start ?? 0xFF16121C,
                                end: _p.fill.end ?? 0xFF3A2140,
                                angle: _p.fill.angle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            skin,
                            'SKIN',
                            !_p.fill.isSet,
                            () => _setFill(BackdropFill.none),
                          ),
                        ],
                      ),
                      if (_p.fill.isSet) ...[
                        const SizedBox(height: 12),
                        Text(
                          _p.fill.isGradient ? 'FROM' : 'COLOUR',
                          style: TextStyle(
                            fontSize: LayoutSpec.fontFloor,
                            fontWeight: FontWeight.w800,
                            color: skin.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _fillSwatches(
                          skin,
                          _p.fill.start ?? 0xFF16121C,
                          (c) => _setFill(_p.fill.copyWith(start: c)),
                        ),
                        if (_p.fill.isGradient) ...[
                          const SizedBox(height: 12),
                          Text(
                            'TO',
                            style: TextStyle(
                              fontSize: LayoutSpec.fontFloor,
                              fontWeight: FontWeight.w800,
                              color: skin.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _fillSwatches(
                            skin,
                            _p.fill.end ?? 0xFF3A2140,
                            (c) => _setFill(_p.fill.copyWith(end: c)),
                          ),
                          _slider(
                            skin,
                            'DIRECTION',
                            _p.fill.angle,
                            0,
                            360,
                            (v) => _setFill(_p.fill.copyWith(angle: v)),
                          ),
                        ],
                      ],
                    ],
                    const SizedBox(height: 18),
                  ],
                  if (_tab == PersonalizeTab.art) ...[
                    SectionBand(skin: skin, label: 'ART FOLDERS'),
                    Row(
                      children: [
                        Expanded(
                          child: _button(
                            skin,
                            'RESCAN',
                            _rescanArt,
                            quiet: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _button(skin, 'ADD PICTURE', _chooseImage),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final folder in widget.state.bundles)
                      _folderCard(skin, folder),
                    const SizedBox(height: 4),
                    const SizedBox(height: 8),
                    Text(
                      widget.state.bundles.isEmpty
                          ? 'No folders yet. A folder is a set of pictures in '
                                'Music/Sonarar/art; a place wears one of them.'
                          : 'Tap a picture in a folder to wear it here. FOLLOW TRACK '
                                'above decides whether the folder walks on with each song.',
                      style: TextStyle(
                        color: skin.textSecondary,
                        fontSize: LayoutSpec.fontFloor - 4,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_tab == PersonalizeTab.home) ...[
                    SectionBand(skin: skin, label: 'HOME'),
                    Text(
                      'NOW stays at the top — it is the page header, not a section.',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontFloor,
                        color: skin.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final section in _orderedSections())
                      _sectionRow(skin, section),
                    const SizedBox(height: 18),
                  ],
                  if (_tab == PersonalizeTab.themes) ...[
                    // The tab already says THEMES; a band repeating it wastes the one
                    // line that could tell you where you stand.
                    Text(
                      widget.state.preset == null
                          ? '${widget.state.allPresets.length} BUILT IN · NONE WORN'
                          : '${widget.state.allPresets.length} AVAILABLE · WEARING '
                                '${widget.state.preset!.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontFloor - 4,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: skin.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final preset in widget.state.allPresets) ...[
                      _themeRow(skin, preset),
                      const SizedBox(height: 6),
                    ],
                    if (widget.onSaveTheme != null)
                      Row(
                        children: [
                          Expanded(
                            child: _button(skin, 'NEW THEME', _saveTheme),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _button(
                              skin,
                              'OVERRIDE',
                              _overrideTheme,
                              quiet: true,
                            ),
                          ),
                        ],
                      ),
                    if (widget.state.preset != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'OVERRIDE writes this look into "${widget.state.preset!.name}", '
                        'the theme you are wearing. NEW THEME keeps this one and starts '
                        'another from it.',
                        style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: LayoutSpec.fontFloor - 4,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (widget.state.preset == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Nothing is worn right now, so there is no theme to override — '
                        'pick one above first, or make a new one.',
                        style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: LayoutSpec.fontFloor - 4,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- preview -------------------------------------------------------------

  /// A miniature of the app, not a colour swatch. It shows the wordmark, the
  /// shape the panels take in this layout, the picture the screen actually
  /// wears, the scrim over it, and the accent where it lands — so a choice can
  /// be judged here instead of by walking back to Home to look.
  Widget _preview(Skin skin) {
    final root = _root;
    final kind = widget.state.layoutId;
    final chrome = widget.state.presentation.kit.chrome;
    final art = widget.state.art;
    final glass = kind == LayoutKind.glass;
    final sonar = kind == LayoutKind.sonar;
    final radius = glass ? 18.0 : (sonar ? 1.0 : 8.0);
    final panel = glass
        ? Colors.white.withValues(alpha: 0.10)
        : (sonar ? Colors.transparent : skin.panel);
    final edge = glass
        ? Colors.white.withValues(alpha: 0.22)
        : skin.textSecondary.withValues(alpha: 0.16);

    Widget row(
      String title,
      String sub, {
      double alpha = 1,
      bool lead = false,
    }) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: panel,
        border: Border.all(color: edge),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          if (lead)
            Container(
              width: 3,
              height: 26,
              margin: const EdgeInsets.only(right: 8),
              color: skin.accent,
            ),
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 8),
            color: skin.accent.withValues(alpha: 0.22),
            child: Icon(
              Icons.music_note_rounded,
              size: 14,
              color: skin.accent.withValues(alpha: alpha),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontFloor - 3,
                    fontWeight: FontWeight.w700,
                    color: skin.textPrimary.withValues(alpha: alpha),
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontFloor - 5,
                    color: skin.textSecondary.withValues(alpha: alpha),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(glass ? 14 : 4),
      child: Container(
        height: 216,
        color: skin.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (art != null)
              FramedArt(
                assetPath: art.assetPath,
                aspect: art.aspect,
                spec: art.spec,
                focus: widget.state.artFocus,
                cacheWidth: 720,
                burn: 1.0,
              )
            else if (_b.isSet && root != null)
              PersonalBackdrop(root: root, spec: _b, skin: skin),
            if (art != null) ArtScrim(color: skin.background),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (chrome.wordmark)
                              Text(
                                'SONARAR',
                                style: TextStyle(
                                  fontSize: LayoutSpec.fontFloor - 2,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: sonar ? 5 : 2,
                                  color: skin.textPrimary,
                                ),
                              ),
                            const SizedBox(height: 3),
                          ],
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: skin.accent,
                          borderRadius: BorderRadius.circular(radius),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 15,
                          color: skin.onAccent,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  row('Beneath the Mask', 'ATLUS Sound Team', lead: sonar),
                  const SizedBox(height: 5),
                  row('Layer Cake', 'Persona 5 · 3:12', alpha: 0.55),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(height: 3, color: skin.accent),
                        ),
                        Expanded(
                          flex: 6,
                          child: Container(
                            height: 3,
                            color: skin.textSecondary.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
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

  // ---- backdrop ------------------------------------------------------------

  /// Re-reads the art folders. Pictures dropped in from a file manager while
  /// the app is open are otherwise invisible until the next launch.
  void _rescanArt() {
    final root = _root;
    if (root == null) return;
    widget.state.setArtBundles(scanArtBundles(root.path));
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.state.bundles.length} art folder'
          '${widget.state.bundles.length == 1 ? '' : 's'} found.',
        ),
      ),
    );
  }

  /// The phone's own pictures, as a sheet of thumbnails. One door for both
  /// "make a folder of art" and "put this photo on a place".
  Future<File?> _pickPictureFromPhone() async {
    final images = candidateImages();
    if (!mounted) return null;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pictures found in Pictures, DCIM or Download.'),
        ),
      );
      return null;
    }
    return showModalBottomSheet<File>(
      context: context,
      backgroundColor: _skin.panel,
      builder: (ctx) => SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.of(ctx).pop(images[i]),
            child: Image.file(
              images[i],
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => ColoredBox(color: _skin.background),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseImage() async {
    final images = candidateImages();
    if (!mounted) return;
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pictures found in Pictures, DCIM or Download.'),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: _skin.panel,
      builder: (ctx) => SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => Navigator.of(ctx).pop(images[i]),
            child: Image.file(
              images[i],
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => ColoredBox(color: _skin.background),
            ),
          ),
        ),
      ),
    );
    final root = _root;
    if (picked == null || root == null || !mounted) return;
    // One picker, then a decision. Choosing a picture and starting a folder
    // used to be two buttons that both opened the same grid.
    final where = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _skin.panel,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.wallpaper_rounded, color: _skin.accent),
              title: Text(
                _surface == null ? 'USE IT EVERYWHERE' : 'USE IT HERE',
                style: TextStyle(color: _skin.textPrimary),
              ),
              onTap: () => Navigator.of(ctx).pop('here'),
            ),
            ListTile(
              leading: Icon(Icons.folder_outlined, color: _skin.accent),
              title: Text(
                'PUT IT IN A FOLDER',
                style: TextStyle(color: _skin.textPrimary),
              ),
              subtitle: Text(
                'Folders hold many pictures and can follow the track.',
                style: TextStyle(color: _skin.textSecondary),
              ),
              onTap: () => Navigator.of(ctx).pop('folder'),
            ),
          ],
        ),
      ),
    );
    if (where == null || !mounted) return;

    if (where == 'folder') {
      final made = createFolderFrom(root.path, picked);
      widget.state.setArtBundles(scanArtBundles(root.path));
      _setBackdrop(
        _b.copyWith(
          artKey:
              '${made.uri.pathSegments.last}/${picked.uri.pathSegments.last}',
          clearFile: true,
        ),
      );
      return;
    }

    final copied = await importBackground(root, picked);
    if (copied == null || !mounted) return;
    _setBackdrop(
      _b.copyWith(file: copied.uri.pathSegments.last, clearArt: true),
    );
  }

  /// What the picture looks like right now, with every slider already applied.
  /// Framing a photo you cannot see is guesswork, and the controls sit below
  /// the fold — so the result travels with you.
  /// One preview per place.
  Widget _scopeStrip(Skin skin) {
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _scopeTile(skin, 'EVERYWHERE', null),
          for (final surface in SurfaceId.values)
            _scopeTile(skin, switch (surface) {
              SurfaceId.home => 'HOME',
              SurfaceId.library => 'LIBRARY',
              SurfaceId.search => 'SEARCH',
              SurfaceId.player => 'PLAYER',
            }, surface),
        ],
      ),
    );
  }

  Widget _scopeTile(Skin skin, String label, SurfaceId? surface) {
    final active = _surface == surface;
    final own = surface == null ? null : _p.surfaces[surface];
    final wears = surface == null ? _b : _p.backdropFor(surface);
    final art = wears.artKey == null
        ? null
        : widget.state.artByKey(wears.artKey!);

    return GestureDetector(
      key: Key('scope-${surface?.name ?? 'everywhere'}'),
      onTap: () => setState(() => _surface = surface),
      child: Container(
        width: 104,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(
            color: active
                ? skin.accent
                : skin.textSecondary.withValues(alpha: 0.25),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRect(
                child: PersonalBackdrop(
                  root: _root,
                  spec: wears,
                  skin: skin,
                  art: art,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              surface == null
                  ? label
                  : (own?.isSet == true ? '• $label' : '↳ $label'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? skin.accent : skin.textSecondary,
                fontSize: LayoutSpec.fontFloor - 5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _picturePreview(Skin skin) {
    if (!_b.isSet) {
      return Container(
        height: 92,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: skin.panel,
          border: Border.all(color: skin.textSecondary.withValues(alpha: 0.22)),
        ),
        child: Text(
          'NO PICTURE — THE SKIN PAINTS THIS',
          style: TextStyle(
            color: skin.textSecondary,
            fontSize: LayoutSpec.fontFloor - 5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
    }

    final root = _root;
    final art = _b.artKey == null ? null : widget.state.artByKey(_b.artKey!);
    // Which frame of which folder this is, so the label means something.
    var at = 1;
    var total = 0;
    for (final folder in widget.state.bundles) {
      final i = folder.set.pieces.indexWhere((p) => p.key == _b.artKey);
      if (i < 0) continue;
      at = i + 1;
      total = folder.set.pieces.length;
      break;
    }

    return ClipRect(
      child: SizedBox(
        height: 148,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PersonalBackdrop(root: root, spec: _b, skin: skin, art: art),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Text(
                      _b.fromArt ? 'FOLDER' : 'PHOTO',
                      style: TextStyle(
                        color: skin.accent,
                        fontSize: LayoutSpec.fontFloor - 6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_b.fromArt && total > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.black.withValues(alpha: 0.55),
                      child: Text(
                        'FRAME $at/$total',
                        style: TextStyle(
                          color: skin.textPrimary,
                          fontSize: LayoutSpec.fontFloor - 6,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
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

  /// Opens the picture full screen for framing.
  Future<void> _reframe() async {
    final root = _root;
    if (root == null) return;
    final file = backdropFile(root, _b);
    if (file == null || !file.existsSync()) return;
    final next = await Navigator.of(context).push<BackdropSpec>(
      MaterialPageRoute(
        builder: (_) =>
            ReframeScreen(skin: widget.state.uiSkin, file: file, initial: _b),
      ),
    );
    if (next != null) _setBackdrop(next);
  }

  // ignore: unused_element
  Widget _focusGrid(Skin skin) {
    final root = _root;
    final file = root == null ? null : backdropFile(root, _b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null)
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 288,
                    errorBuilder: (_, __, ___) => ColoredBox(color: skin.panel),
                  ),
                GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var row = 0; row < 3; row++)
                      for (var col = 0; col < 3; col++)
                        GestureDetector(
                          onTap: () => _setBackdrop(
                            _b.copyWith(
                              focusX: (col + 0.5) / 3,
                              focusY: (row + 0.5) / 3,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    ((_b.focusX * 3).floor() == col &&
                                        (_b.focusY * 3).floor() == row)
                                    ? skin.accent
                                    : Colors.white24,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap the part of the picture that matters. It stays centred whatever '
              'shape the screen is.',
              style: TextStyle(
                fontSize: LayoutSpec.fontFloor,
                color: skin.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- accent --------------------------------------------------------------

  /// Base colours: four darks, a mid grey, then light stock.
  static final List<Color> _bases = [
    for (final c in const [0xFF060606, 0xFF101014, 0xFF1A1512, 0xFF22262B,
      0xFF2E3238, 0xFF5A5F66, 0xFFDDD8CE, 0xFFF3EFE7])
      Color(c),
  ];

  /// Twelve hues, then paper to pitch.
  static final List<Color> _swatches = [
    for (var i = 0; i < 12; i++)
      HSLColor.fromAHSL(1, i * 30.0, 0.68, 0.58).toColor(),
    for (final light in const [0.95, 0.80, 0.62, 0.45, 0.28, 0.12])
      HSLColor.fromAHSL(1, 0, 0, light).toColor(),
  ];

  /// Choosing FROM PHOTO takes the colour straight away. It used to only
  /// declare the source and then wait for a second button, which reads as a
  /// chip that does nothing.

  // ---- home ----------------------------------------------------------------

  List<HomeSection> _orderedSections() => [
    for (final s in _p.home.all)
      if (s != HomeSection.now) s,
  ];

  String _sectionName(HomeSection s) => switch (s) {
    HomeSection.now => 'NOW',
    HomeSection.continueListening => 'CONTINUE LISTENING',
    HomeSection.recentlyAdded => 'RECENTLY ADDED',
    HomeSection.rediscover => 'REDISCOVER',
    HomeSection.jumpBackIn => 'JUMP BACK IN',
    HomeSection.quickPick => 'QUICK PICK',
    HomeSection.fromLibrary => 'FROM YOUR LIBRARY',
    HomeSection.recap => 'RECAP',
  };

  Widget _sectionRow(Skin skin, HomeSection section) {
    final order = _orderedSections();
    final index = order.indexOf(section);
    return Padding(
      key: ValueKey('home-row-${section.name}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sectionName(section),
              style: TextStyle(
                fontSize: LayoutSpec.fontFloor,
                fontWeight: FontWeight.w800,
                color: skin.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: index <= 0
                ? null
                : () => _apply(
                    _p.copyWith(home: _p.home.move(section, index - 1)),
                  ),
            icon: Icon(
              Icons.keyboard_arrow_up_rounded,
              color: skin.textPrimary,
            ),
          ),
          IconButton(
            onPressed: index < 0 || index >= order.length - 1
                ? null
                : () => _apply(
                    _p.copyWith(home: _p.home.move(section, index + 1)),
                  ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: skin.textPrimary,
            ),
          ),
          Switch(
            value: !_p.home.hidden.contains(section),
            activeThumbColor: skin.accent,
            onChanged: (_) =>
                _apply(_p.copyWith(home: _p.home.toggle(section))),
          ),
        ],
      ),
    );
  }

  // ---- themes --------------------------------------------------------------

  Future<void> _saveTheme() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _skin.panel,
        title: Text(
          'Name the new theme',
          style: TextStyle(color: _skin.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _skin.textPrimary),
          decoration: const InputDecoration(hintText: 'Midnight harbour'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('CREATE'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    widget.onSaveTheme?.call(name);
  }

  void _overrideTheme() {
    final name = widget.state.preset?.name;
    final done = widget.state.overrideActiveTheme();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? 'Saved into "$name".'
              : 'No theme is worn, so there was nothing to override.',
        ),
      ),
    );
  }

  void _setFill(BackdropFill fill) => _apply(_p.copyWith(fill: fill));

  Widget _fillSwatches(Skin skin, int selected, ValueChanged<int> onPick) {
    const colours = [
      0xFF0B0B10,
      0xFF16121C,
      0xFF1D2A33,
      0xFF2A1B2E,
      0xFF3A2140,
      0xFF12303A,
      0xFF4A1F1F,
      0xFF2B3A1E,
      0xFF3B2E18,
      0xFFE3B84E,
      0xFFD97655,
      0xFFB8C4CE,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in colours)
          GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Color(c),
                border: Border.all(
                  color: c == selected
                      ? skin.accent
                      : skin.textSecondary.withValues(alpha: 0.3),
                  width: c == selected ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---- bits ----------------------------------------------------------------

  void _prefs(AppPrefs Function(AppPrefs) edit) {
    final prefs = widget.prefs;
    if (prefs == null) return;
    widget.onPrefsChanged?.call(edit(prefs));
    setState(() {});
  }

  void _setGrid(bool grid) {
    final prefs = widget.prefs;
    if (prefs == null) return;
    widget.onPrefsChanged?.call(prefs.copyWith(libraryIsGrid: grid));
    setState(() {});
  }

  Widget _layoutTile(Skin skin, LayoutKind kind) {
    final active = widget.state.layoutId == kind;
    return GestureDetector(
      onTap: () {
        final prefs = widget.prefs;
        if (prefs == null) return;
        widget.onPrefsChanged?.call(prefs.copyWith(layoutId: kind.name));
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? skin.accent : skin.panel,
          border: Border.all(color: skin.accent, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              switch (kind) {
                LayoutKind.sonar => Icons.auto_awesome_rounded,
                LayoutKind.solid => Icons.crop_square_rounded,
                LayoutKind.glass => Icons.blur_on_rounded,
              },
              size: 20,
              color: active ? skin.onAccent : skin.accent,
            ),
            const SizedBox(height: 6),
            Text(
              switch (kind) {
                LayoutKind.sonar => 'SONAR',
                LayoutKind.solid => 'SOLID',
                LayoutKind.glass => 'GLASS',
              },
              style: TextStyle(
                fontSize: LayoutSpec.fontFloor,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color: active ? skin.onAccent : skin.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeSwatch(Skin theme, bool active) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: theme.background,
      border: Border.all(
        color: active
            ? theme.accent
            : theme.textSecondary.withValues(alpha: 0.5),
        width: active ? 2 : 1,
      ),
    ),
    alignment: Alignment.bottomRight,
    child: Container(width: 9, height: 9, color: theme.accent),
  );

  Widget _themeRow(Skin skin, ThemePreset preset) {
    final active = widget.state.preset?.id == preset.id;
    return GestureDetector(
      onTap: () {
        widget.onApplyTheme?.call(preset);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: active ? skin.accent.withValues(alpha: 0.16) : skin.panel,
          border: Border(
            // One spine, one meaning: accent on the theme you are wearing,
            // quiet grey on the rest. Six lime spines said nothing.
            left: BorderSide(
              color: active
                  ? skin.accent
                  : skin.textSecondary.withValues(alpha: 0.35),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // A theme called Abyss or Crimson is a colour, and a name alone
            // makes six of them a reading exercise. The swatch is the theme's
            // own two colours: its ground and its accent.
            _themeSwatch(skinFor(preset.skinId), active),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.name,
                style: TextStyle(
                  fontSize: LayoutSpec.fontFloor,
                  fontWeight: FontWeight.w800,
                  color: skin.textPrimary,
                ),
              ),
            ),
            if (active)
              Text(
                'WORN',
                style: TextStyle(
                  fontSize: LayoutSpec.fontFloor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: skin.accent,
                ),
              )
            else if (preset.builtIn)
              Text(
                'BUILT IN',
                style: TextStyle(
                  fontSize: LayoutSpec.fontFloor,
                  color: skin.textSecondary,
                ),
              )
            else
              IconButton(
                onPressed: () {
                  widget.onDeleteTheme?.call(preset);
                  setState(() {});
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: skin.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The parts of the look, as tabs. One page at a time, so the screen has a
  /// bottom and you can see what you have already set.
  Widget _tabs(Skin skin) => KitTabs<PersonalizeTab>(
    skin: skin,
    labels: const {
      PersonalizeTab.themes: 'THEMES',
      PersonalizeTab.look: 'LOOK',
      PersonalizeTab.art: 'ART',
      PersonalizeTab.home: 'HOME',
    },
    selected: _tab,
    onSelected: (t) => setState(() => _tab = t),
    keyBuilder: (t) => Key('personalize-tab-${t.name}'),
  );

  Widget _toggleRow(
    Skin skin,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => KitToggle(
    skin: skin,
    label: label,
    value: value,
    onChanged: onChanged,
  );

  Widget _button(
    Skin skin,
    String label,
    VoidCallback onTap, {
    bool quiet = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        // Quiet means "not the main move", not "unavailable": it keeps full
        // contrast, since a button that looks disabled has to be explained.
        color: quiet ? skin.panel : skin.accent,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: quiet ? skin.textPrimary : skin.onAccent,
          ),
        ),
      ),
    ),
  );

  /// [marked] shows a place that has its own picture even while you are
  /// looking at another one, so the selector answers "where is custom?".
  /// One picture in the picker: the picture itself, its name underneath, and
  /// a ring when it is the one being worn.
  /// Copies a picture into `art/` and wears it here.
  ///
  /// A folder holds a set — that is what makes FOLLOW TRACK possible — so this
  /// asks whether the picture starts a new folder or joins one already there,
  /// instead of making a folder of one every time.
  /// One row per art folder: its pictures, and the three things you do to a
  /// folder — add to it, rename it, delete it. A folder is a set, so removing a
  /// picture happens on the picture, not in a menu.
  Widget _folderCard(Skin skin, ArtBundle folder) {
    final worn = folder.set.pieces.any((p) => p.key == _b.artKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: skin.panel,
        border: Border(
          left: BorderSide(
            color: worn
                ? skin.accent
                : skin.textSecondary.withValues(alpha: 0.3),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${folder.name.toUpperCase()}  ·  '
                  '${folder.set.pieces.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: worn ? skin.accent : skin.textPrimary,
                    fontSize: LayoutSpec.fontFloor - 3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _miniAction(
                skin,
                Icons.add_photo_alternate_outlined,
                'ADD',
                () => _addToFolder(folder),
              ),
              _miniAction(
                skin,
                Icons.drive_file_rename_outline,
                'RENAME',
                () => _renameFolder(folder),
              ),
              _miniAction(
                skin,
                Icons.delete_outline,
                'DELETE',
                () => _deleteFolder(folder),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final piece in folder.set.pieces)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Stack(
                      children: [
                        GestureDetector(
                          key: Key('folder-frame-${piece.key}'),
                          onTap: () => _setPic(piece.key),
                          child: SizedBox(
                            width: 62,
                            height: 46,
                            child: piece.assetPath.startsWith('file:')
                                ? Image.file(
                                    File(piece.assetPath.substring(5)),
                                    fit: BoxFit.cover,
                                    cacheWidth: 186,
                                    errorBuilder: (_, __, ___) =>
                                        ColoredBox(color: skin.background),
                                  )
                                : Image.asset(
                                    piece.assetPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        ColoredBox(color: skin.background),
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removePiece(folder, piece),
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(1),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: skin.textPrimary,
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
        ],
      ),
    );
  }

  Widget _miniAction(
    Skin skin,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: skin.textSecondary),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: skin.textSecondary,
              fontSize: LayoutSpec.fontFloor - 5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _addToFolder(ArtBundle folder) async {
    final root = _root;
    if (root == null) return;
    final picked = await _pickPictureFromPhone();
    if (picked == null || !mounted) return;
    addToFolder(Directory('${root.path}/art/${folder.name}'), picked);
    widget.state.setArtBundles(scanArtBundles(root.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Added to ${folder.name}.')));
  }

  Future<String?> _askFolderName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _skin.panel,
        title: Text(
          'FOLDER NAME',
          style: TextStyle(
            color: _skin.textPrimary,
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        content: TextField(
          key: const Key('folder-name-field'),
          controller: controller,
          autofocus: true,
          style: TextStyle(color: _skin.textPrimary),
          decoration: InputDecoration(
            hintText: 'Night drives',
            hintStyle: TextStyle(color: _skin.textSecondary),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('CANCEL', style: TextStyle(color: _skin.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _skin.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _accentFromPhoto() async {
    final root = _root;
    if (root == null) return;
    var file = backdropFile(root, _b);
    if (file == null) {
      // No photo yet: take one. The accent is the photo, so ask for it here
      // instead of pointing at a button on another band.
      await _chooseImage();
      if (!mounted) return;
      file = backdropFile(root, _b);
    }
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photo chosen, so no colour taken.')),
      );
      return;
    }
    final colour = await accentFromImage(file);
    if (!mounted) return;
    if (colour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That picture has no colour strong enough to be an accent.',
          ),
        ),
      );
      return;
    }
    final argb = colour.toARGB32();
    _apply(
      _p.copyWith(
        accent: AccentSpec(source: AccentSource.image, value: argb),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Accent taken from the photo: '
          '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        ),
      ),
    );
  }

  Future<void> _renameFolder(ArtBundle folder) async {
    final root = _root;
    if (root == null) return;
    final name = await _askFolderName();
    if (name == null || !mounted) return;
    final renamed = renameFolder(
      Directory('${root.path}/art/${folder.name}'),
      name,
    );
    final newName = renamed.path.split(Platform.pathSeparator).last;
    widget.state.setArtBundles(scanArtBundles(root.path));
    if (_p.bundle == folder.name) _apply(_p.copyWith(bundle: newName));
  }

  Future<void> _deleteFolder(ArtBundle folder) async {
    final root = _root;
    if (root == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _skin.panel,
        title: Text(
          'DELETE ${folder.name.toUpperCase()}?',
          style: TextStyle(
            color: _skin.textPrimary,
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'The ${folder.set.pieces.length} pictures in this folder are deleted '
          'with it. Your originals on the phone are untouched.',
          style: TextStyle(
            color: _skin.textSecondary,
            fontSize: LayoutSpec.fontFloor - 3,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('KEEP', style: TextStyle(color: _skin.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'DELETE',
              style: TextStyle(
                color: _skin.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (folder.set.pieces.any((p) => p.key == _b.artKey)) _setPic(null);
    deleteFolder(Directory('${root.path}/art/${folder.name}'));
    widget.state.setArtBundles(scanArtBundles(root.path));
  }

  void _removePiece(ArtBundle folder, SkinArt piece) {
    final root = _root;
    if (root == null) return;
    if (folder.set.pieces.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is the only picture left — delete the folder.'),
        ),
      );
      return;
    }
    removeFromFolder(
      Directory('${root.path}/art/${folder.name}'),
      piece.assetPath.startsWith('file:')
          ? piece.assetPath.substring(5).split(Platform.pathSeparator).last
          : piece.assetPath.split('/').last,
    );
    if (_b.artKey == piece.key) _setPic(null);
    widget.state.setArtBundles(scanArtBundles(root.path));
  }

  Widget _chip(
    Skin skin,
    String label,
    bool active,
    VoidCallback onTap, {
    bool marked = false,
  }) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? skin.accent : skin.panel,
        border: Border.all(
          color: active
              ? skin.accent
              : skin.textSecondary.withValues(alpha: 0.4),
          width: marked && !active ? 2 : 1,
        ),
      ),
      child: Text(
        marked && !active ? '• $label' : label,
        style: TextStyle(
          fontSize: LayoutSpec.fontFloor,
          fontWeight: FontWeight.w900,
          color: active ? skin.onAccent : skin.textPrimary,
        ),
      ),
    ),
  );

  Widget _slider(
    Skin skin,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? shown,
  }) => KitSlider(
    skin: skin,
    label: label,
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
    shown: shown ?? value.toStringAsFixed(value <= 1 ? 2 : 0),
  );

  Widget _toggle(
    Skin skin,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => KitToggle(
    skin: skin,
    label: label,
    value: value,
    onChanged: onChanged,
    dense: true,
  );
}
