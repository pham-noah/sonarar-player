library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/prefs.dart';
import '../theme/layout.dart';
import '../theme/theme_preset.dart';
import '../art/art_bundle.dart';
import '../art/art_spec.dart';
import '../screens/art_editor_screen.dart';
import '../theme/backdrop_import.dart';
import '../theme/backdrop_layer.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import '../widgets/devices.dart';

/// PERSONALIZE — the one place the app's look is decided.
///
/// Everything about the look lives here: the layout, the songs' shape, what is
/// painted behind each tab, where the accent comes from, and which Home
/// sections show in which order. Settings keeps behaviour only, so there is one
/// place to look instead of two that half-overlap.
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.arrow_back_rounded, color: skin.textPrimary),
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
            const SizedBox(height: 8),
            _preview(skin),
            const SizedBox(height: 20),

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
                'Framing follows EVERYWHERE. Pick a place to give it its own '
                'picture; the sliders below stay with the default.',
                style: TextStyle(
                  color: skin.textSecondary,
                  fontSize: LayoutSpec.fontFloor - 4,
                  height: 1.4,
                ),
              ),
            ],
            if (_b.isSet && _surface == null) ...[
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
            ],
            const SizedBox(height: 18),

            SectionBand(skin: skin, label: 'ART'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  skin,
                  'BUILT IN',
                  _wornBundle == null && _surfaceArt == null,
                  () => _setArt(null),
                ),
                for (final bundle in widget.state.bundles)
                  _chip(
                    skin,
                    bundle.name.toUpperCase(),
                    _surface == null
                        ? _p.bundle == bundle.name
                        : _surfaceArt == bundle.set.pieces.first.key,
                    () => _setArt(bundle.name),
                    marked:
                        _surface != null && _p.surfaces[_surface!]?.art != null,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _button(skin, 'NEW BUNDLE FROM A PICTURE', _newBundle),
                ),
                const SizedBox(width: 8),
                if (_wornBundle != null)
                  Expanded(child: _button(skin, 'ADJUST', _adjustArt)),
              ],
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
                    () => _apply(
                      _p.copyWith(
                        accent: AccentSpec(
                          source: source,
                          value: _p.accent.value,
                        ),
                      ),
                    ),
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

            SectionBand(skin: skin, label: 'THEMES'),
            for (final preset in widget.state.allPresets) ...[
              _themeRow(skin, preset),
              const SizedBox(height: 6),
            ],
            if (widget.onSaveTheme != null)
              _button(skin, 'SAVE THIS LOOK AS A THEME', _saveTheme),
          ],
        ),
      ),
    );
  }

  // ---- preview -------------------------------------------------------------

  Widget _preview(Skin skin) {
    final root = _root;
    return Container(
      height: 168,
      color: skin.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_b.isSet && root != null)
            PersonalBackdrop(root: root, spec: _b, skin: skin),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.greeting ?? 'SONARAR',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontTitle,
                    fontWeight: FontWeight.w900,
                    color: skin.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 44, height: 44, color: skin.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accent on the panel',
                            style: TextStyle(
                              fontSize: LayoutSpec.fontFloor,
                              color: skin.textPrimary,
                            ),
                          ),
                          Text(
                            'secondary line',
                            style: TextStyle(
                              fontSize: LayoutSpec.fontFloor,
                              color: skin.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  void _setArt(String? bundleName) {
    if (_surface == null) {
      _apply(
        bundleName == null
            ? _p.copyWith(clearBundle: true)
            : _p.copyWith(bundle: bundleName),
      );
      return;
    }
    String? key;
    for (final bundle in widget.state.bundles) {
      if (bundle.name == bundleName) key = bundle.set.pieces.first.key;
    }
    final look = (_p.surfaces[_surface!] ?? const SurfaceLook()).copyWith(
      art: key,
      clearArt: key == null,
    );
    _apply(_p.withSurface(_surface!, look));
  }

  Future<void> _adjustArt() async {
    final bundle = _wornBundle;
    final root = _root;
    if (bundle == null || root == null) return;
    final piece = bundle.set.pieces.first;

    final dir = Directory('${root.path}/art/${bundle.name}');
    final saved = await Navigator.of(context).push<ArtSpec>(
      MaterialPageRoute(
        builder: (_) => ArtEditorScreen(
          skin: _skin,
          bundle: dir,
          assetPath: piece.assetPath,
          aspect: piece.aspect,
          focus: piece.focus,
          initial: ArtSpec.read(dir),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    widget.state.setArtBundles(scanArtBundles(root.path));
    setState(() {});
  }

  /// Starts a bundle around one picture the user already has. The folder can
  /// take more frames afterwards; this is only the first one.
  Future<void> _newBundle() async {
    final root = _root;
    if (root == null) return;
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
    if (picked == null || !mounted) return;
    final dir = createBundleFrom(root.path, picked);
    final name = dir.path.split(Platform.pathSeparator).last;
    widget.state.setArtBundles(scanArtBundles(root.path));
    _apply(_p.copyWith(bundle: name));
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

  Future<void> _accentFromPhoto() async {
    final root = _root;
    if (root == null) return;
    final file = backdropFile(root, _b);
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a backdrop first — that is the photo.'),
        ),
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
    _apply(
      _p.copyWith(
        accent: AccentSpec(
          source: AccentSource.image,
          value: colour.toARGB32(),
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
          'Name this look',
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
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    widget.onSaveTheme?.call(name);
  }

  // ---- bits ----------------------------------------------------------------

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
            if (preset.builtIn)
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

  Widget _button(
    Skin skin,
    String label,
    VoidCallback onTap, {
    bool quiet = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        color: quiet ? skin.panel : skin.accent,
        child: Text(
          label,
          textAlign: TextAlign.center,
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
  Widget _chip(
    Skin skin,
    String label,
    bool active,
    VoidCallback onTap, {
    bool marked = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
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
  ) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label  ${value.toStringAsFixed(value <= 1 ? 2 : 0)}',
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            fontWeight: FontWeight.w800,
            color: skin.textSecondary,
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: skin.accent,
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _toggle(
    Skin skin,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: LayoutSpec.fontFloor,
            color: skin.textPrimary,
          ),
        ),
      ),
      Switch(value: value, activeThumbColor: skin.accent, onChanged: onChanged),
    ],
  );
}
