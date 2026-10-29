library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../theme/theme_preset.dart';
import '../widgets/kit.dart';
import '../widgets/spectrum.dart';
import '../art/art_bundle.dart';
import '../art/art_spec.dart';
import '../art/skin_art.dart';
import '../screens/art_editor_screen.dart';
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
enum PersonalizeTab { themes, look, pictures, art, home }

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

  void _setBackdrop(BackdropSpec b) {
    if (_surface == null) {
      _apply(_p.copyWith(backdrop: b));
      return;
    }
    // A per-place picture is the picture only; the framing sliders stay with
    // the default, so one photo cannot end up cropped four different ways.
    _apply(_p.withSurface(_surface!, SurfaceLook(room: b.file)));
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
                          color: skin.textPrimary,
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
                  _preview(skin),
                  const SizedBox(height: 14),

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
              'The screens travel into place when you change tab.',
              widget.prefs?.tabAnimation ?? true,
              (v) => _prefs((p) => p.copyWith(tabAnimation: v)),
            ),
            _toggleRow(
              skin,
              'SPECTRUM',
              'Bars under the player, following the music.',
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
                (v) => _prefs((p) => p.copyWith(spectrumSmoothness: v.round())),
              ),
              _slider(
                skin,
                'SCALE',
                widget.prefs?.spectrumScalePercent.toDouble() ?? 100,
                40,
                220,
                (v) => _prefs((p) => p.copyWith(spectrumScale: v.round())),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final shape in SpectrumShape.values)
                    _chip(
                      skin,
                      shape.label,
                      widget.prefs?.spectrumShapeName == shape.name,
                      () => _prefs(
                        (p) => p.copyWith(spectrumShape: shape.name),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            SectionBand(skin: skin, label: 'ACCENT'),
            Wrap(
              spacing: 8,
              children: [
                for (final source in AccentSource.values)
                  _chip(
                    skin,
                    switch (source) {
                      AccentSource.skin => 'SKIN',
                      AccentSource.image => 'FROM PHOTO',
                      AccentSource.manual => 'PICK',
                    },
                    _p.accent.source == source,
                    () => _setAccentSource(source),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_p.accent.source == AccentSource.image)
              _button(
                skin,
                'TAKE THE COLOUR FROM THE PHOTO',
                _accentFromPhoto,
                quiet: true,
              ),
            if (_p.accent.source == AccentSource.manual) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colour in _swatches)
                    GestureDetector(
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
                        height: 38,
                        decoration: BoxDecoration(
                          color: colour,
                          border: Border.all(
                            color: _p.accent.value == colour.toARGB32()
                                ? skin.textPrimary
                                : skin.textSecondary.withValues(alpha: 0.4),
                            width: _p.accent.value == colour.toARGB32() ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            ],
            if (_tab == PersonalizeTab.pictures) ...[
            SectionBand(skin: skin, label: 'PICTURES FOR'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  skin,
                  'EVERYWHERE',
                  _surface == null,
                  () => setState(() => _surface = null),
                ),
                for (final surface in SurfaceId.values)
                  _chip(
                    skin,
                    switch (surface) {
                      SurfaceId.home => 'HOME',
                      SurfaceId.library => 'LIBRARY',
                      SurfaceId.search => 'SEARCH',
                      SurfaceId.player => 'PLAYER',
                    },
                    _surface == surface,
                    () => setState(() => _surface = surface),
                    marked: _p.surfaces[surface]?.isSet == true,
                  ),
              ],
            ),

            const SizedBox(height: 10),
            // Pictures, not folder names. A row of names asks you to remember
            // what "TEST-BUNDLE" looks like; a row of pictures shows you.
            SizedBox(
              height: 132,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _artTile(
                    skin,
                    label: 'BUILT IN',
                    selected: _surface == null
                        ? _p.bundle == null
                        : _surfaceArt == null,
                    onTap: () => _setArt(null),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 26,
                      color: skin.textSecondary,
                    ),
                  ),
                  if (_surface == null)
                    for (final bundle in widget.state.bundles)
                      _artTile(
                        skin,
                        label: bundle.name.toUpperCase(),
                        selected: _p.bundle == bundle.name,
                        onTap: () => _setArt(bundle.name),
                        piece: bundle.set.pieces.first,
                      )
                  else
                    for (final bundle in widget.state.bundles)
                      for (final piece in bundle.set.pieces)
                        _artTile(
                          skin,
                          // One folder can hold many pictures; a place wears
                          // one of them, so every picture is its own tile.
                          label: bundle.set.pieces.length == 1
                              ? bundle.name.toUpperCase()
                              : '${bundle.name.toUpperCase()} '
                                  '${bundle.set.pieces.indexOf(piece) + 1}',
                          selected: _p.surfaces[_surface!]?.art == piece.key,
                          onTap: () => _setArt(bundle.name, pieceKey: piece.key),
                          piece: piece,
                        ),
                  _artTile(
                    skin,
                    label: 'FROM PHONE',
                    selected: false,
                    onTap: _pickPictureForPlace,
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 26,
                      color: skin.accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _surface == null
                  ? 'EVERYWHERE wears one art folder and moves through its '
                      'pictures as tracks change. Pick a place for one picture.'
                  : 'This place wears one picture. Framing belongs to the '
                      'picture, so the same photo can be cropped differently '
                      'here and on the player.',
              style: TextStyle(
                color: skin.textSecondary,
                fontSize: LayoutSpec.fontFloor - 4,
                height: 1.4,
              ),
            ),
            if (_wornPiece != null) ...[
              const SizedBox(height: 10),
              _button(skin, 'ADJUST FRAMING', _adjustArt),
            ],
            const SizedBox(height: 18),

            SectionBand(skin: skin, label: 'BACKDROP'),
            Row(
              children: [
                Expanded(child: _button(skin, 'CHOOSE IMAGE', _chooseImage)),
                const SizedBox(width: 8),
                if (_b.isSet)
                  Expanded(
                    child: _button(
                      skin,
                      'REMOVE',
                      () => _setBackdrop(const BackdropSpec()),
                      quiet: true,
                    ),
                  ),
              ],
            ),
            if (_b.isSet && _surface != null) ...[
              const SizedBox(height: 10),
              Text(
                'Framing follows EVERYWHERE: these sliders move this picture '
                'wherever it is used, not just here.',
                style: TextStyle(
                  color: skin.textSecondary,
                  fontSize: LayoutSpec.fontFloor - 4,
                  height: 1.4,
                ),
              ),
            ],
            if (_b.isSet) ...[
              const SizedBox(height: 14),
              _focusGrid(skin),
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
                3,
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
                  child: _button(skin, 'NEW BUNDLE FROM A PICTURE', _newBundle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _button(skin, 'RESCAN', _rescanArt, quiet: true),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _toggleRow(
              skin,
              'PICTURES FOLLOW TRACK',
              'Each new song moves on to the next picture in the bundle.',
              widget.prefs?.cycleCharacterArt ?? false,
              (v) => widget.onPrefsChanged?.call(
                widget.prefs!.copyWith(cycleCharacterArt: v),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A bundle is a folder of pictures in Music/Sonarar/art. Every '
              'picture in it is a frame of that art; drop more in and it has '
              'more. ${widget.state.bundles.isEmpty ? 'No folders yet.' : ''}',
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

    Widget row(String title, String sub, {double alpha = 1, bool lead = false}) =>
        Container(
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
                child: Icon(Icons.music_note_rounded,
                    size: 14, color: skin.accent.withValues(alpha: alpha)),
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
                            Text(
                              widget.greeting ?? 'Good evening',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: LayoutSpec.fontTitle - 4,
                                fontWeight: FontWeight.w900,
                                color: skin.textPrimary,
                              ),
                            ),
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
                        child: Icon(Icons.play_arrow_rounded,
                            size: 15, color: skin.onAccent),
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

  /// The bundle this place wears, if it wears one.
  ArtBundle? get _wornBundle {
    final name = _surface == null ? _p.bundle : null;
    for (final bundle in widget.state.bundles) {
      if (bundle.name == name) return bundle;
      if (_surface != null && bundle.set.pieces.first.key == _surfaceArt) {
        return bundle;
      }
    }
    return null;
  }

  String? get _surfaceArt =>
      _surface == null ? null : _p.surfaces[_surface!]?.art;

  /// Picking art is picking it for the place you are looking at, when a place is
  /// selected. There is one art bundle in the app; places choose pictures from
  /// it rather than each carrying a private copy.
  void _setArt(String? bundleName, {String? pieceKey}) {
    if (_surface == null) {
      _apply(
        bundleName == null
            ? _p.copyWith(clearBundle: true)
            : _p.copyWith(bundle: bundleName),
      );
      return;
    }
    String? key = pieceKey;
    for (final bundle in widget.state.bundles) {
      if (bundle.name != bundleName) continue;
      key ??= bundle.set.pieces.first.key;
    }
    final look = (_p.surfaces[_surface!] ?? const SurfaceLook()).copyWith(
      art: key,
      clearArt: key == null,
    );
    _apply(_p.withSurface(_surface!, look));
  }

  /// Opens the editor for whatever picture this place wears — a bundle picture,
  /// whose framing lives beside it, or a shipped one, whose framing lives in the
  /// look file because an APK cannot be written to.
  Future<void> _adjustArt() async {
    final piece = _wornPiece;
    final root = _root;
    if (piece == null) return;

    final bundle = _wornBundle;
    final dir = bundle == null || root == null
        ? null
        : Directory('${root.path}/art/${bundle.name}');

    final saved = await Navigator.of(context).push<ArtSpec>(
      MaterialPageRoute(
        builder: (_) => ArtEditorScreen(
          skin: _skin,
          assetPath: piece.assetPath,
          aspect: piece.aspect,
          focus: piece.focus,
          initial: dir == null
              ? widget.state.specFor(piece)
              : ArtSpec.read(dir),
        ),
      ),
    );
    if (saved == null || !mounted) return;

    if (dir != null) {
      ArtSpec.write(dir, saved);
      if (root != null) widget.state.setArtBundles(scanArtBundles(root.path));
    } else {
      _apply(_p.withArtSpec(piece.key, saved));
    }
    setState(() {});
  }

  /// Re-reads the art folders. Pictures dropped in from a file manager while
  /// the app is open are otherwise invisible until the next launch.
  void _rescanArt() {
    final root = _root;
    if (root == null) return;
    widget.state.setArtBundles(scanArtBundles(root.path));
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.state.bundles.length} art folder'
          '${widget.state.bundles.length == 1 ? '' : 's'} found.'),
    ));
  }

  /// The picture currently being framed: a place's own, or the global one.
  SkinArt? get _wornPiece {
    if (_surface != null) {
      final own = widget.state.artForSurface(_surface!);
      if (own != null && _surfaceArt != null) return own;
    }
    return widget.state.art;
  }

  /// Starts a bundle around one picture the user already has. The folder can
  /// take more frames afterwards; this is only the first one.
  Future<void> _newBundle() async {
    final root = _root;
    if (root == null) return;
    final picked = await _pickPictureFromPhone();
    if (picked == null || !mounted) return;
    final dir = createBundleFrom(root.path, picked);
    final name = dir.path.split(Platform.pathSeparator).last;
    widget.state.setArtBundles(scanArtBundles(root.path));
    _apply(_p.copyWith(bundle: name));
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
              errorBuilder: (_, __, ___) => ColoredBox(color: _skin.background),
            ),
          ),
        ),
      ),
    );
    final root = _root;
    if (picked == null || root == null) return;
    final copied = await importBackground(root, picked);
    if (copied == null || !mounted) return;
    _setBackdrop(_b.copyWith(file: copied.uri.pathSegments.last));
  }

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

  static const List<Color> _swatches = [
    Color(0xFFE3B84E),
    Color(0xFFD2455B),
    Color(0xFF3BA7C8),
    Color(0xFF7F62C9),
    Color(0xFF3FA96B),
    Color(0xFFE07B39),
    Color(0xFFB8C4CE),
    Color(0xFFE8E2D6),
  ];

  /// Choosing FROM PHOTO takes the colour straight away. It used to only
  /// declare the source and then wait for a second button, which reads as a
  /// chip that does nothing.
  Future<void> _setAccentSource(AccentSource source) async {
    _apply(
      _p.copyWith(
        accent: AccentSpec(source: source, value: _p.accent.value),
      ),
    );
    if (source == AccentSource.image) await _accentFromPhoto();
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
      0xFF0B0B10, 0xFF16121C, 0xFF1D2A33, 0xFF2A1B2E,
      0xFF3A2140, 0xFF12303A, 0xFF4A1F1F, 0xFF2B3A1E,
      0xFF3B2E18, 0xFFE3B84E, 0xFFD97655, 0xFFB8C4CE,
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
                  color: c == selected ? skin.accent : skin.textSecondary.withValues(alpha: 0.3),
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
        color: active ? theme.accent : theme.textSecondary.withValues(alpha: 0.5),
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
            left: BorderSide(color: skin.accent, width: active ? 3 : 1),
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
      PersonalizeTab.pictures: 'PICTURES',
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
    String note,
    bool value,
    ValueChanged<bool> onChanged,
  ) => KitToggle(
    skin: skin,
    label: label,
    note: note,
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
  Widget _artTile(
    Skin skin, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    SkinArt? piece,
    Widget? child,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: skin.panel,
                    border: Border.all(
                      color: selected
                          ? skin.accent
                          : skin.textSecondary.withValues(alpha: 0.22),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: piece == null
                      ? Center(child: child)
                      : _ArtThumb(piece: piece.assetPath),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: LayoutSpec.fontFloor - 4,
                    letterSpacing: 0.8,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? skin.accent : skin.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// Copies the chosen picture into `art/` and wears it here.
  ///
  /// A bundle is the only kind of picture the app can frame, name and keep
  /// after a reboot, so a phone photo becomes a bundle of one rather than a
  /// path stored on its own.
  Future<void> _pickPictureForPlace() async {
    final root = _root;
    if (root == null) return;
    final picked = await _pickPictureFromPhone();
    if (picked == null || !mounted) return;

    final dir = createBundleFrom(root.path, picked);
    final name = dir.path.split(Platform.pathSeparator).last;
    widget.state.setArtBundles(scanArtBundles(root.path));
    String? key;
    for (final bundle in widget.state.bundles) {
      if (bundle.name == name) key = bundle.set.pieces.first.key;
    }
    setState(() {
      if (_surface == null) {
        _apply(_p.copyWith(bundle: name));
      } else if (key != null) {
        _apply(
          _p.withSurface(
            _surface!,
            (_p.surfaces[_surface!] ?? const SurfaceLook()).copyWith(art: key),
          ),
        );
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _surface == null
              ? 'That picture is now the everywhere art.'
              : 'That picture now hangs here — frame it with ADJUST FRAMING.',
        ),
      ),
    );
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
    ValueChanged<double> onChanged,
  ) => KitSlider(
    skin: skin,
    label: label,
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
    shown: value.toStringAsFixed(value <= 1 ? 2 : 0),
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

/// A picture from a bundle, at thumbnail size. Bundles point at files on the
/// card (`file:` prefix); shipped art is an asset. One widget, both kinds.
class _ArtThumb extends StatelessWidget {
  const _ArtThumb({required this.piece});

  final String piece;

  @override
  Widget build(BuildContext context) {
    if (piece.startsWith('file:')) {
      return Image.file(
        File(piece.substring(5)),
        fit: BoxFit.cover,
        cacheWidth: 192,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Image.asset(
      piece,
      fit: BoxFit.cover,
      cacheWidth: 192,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
