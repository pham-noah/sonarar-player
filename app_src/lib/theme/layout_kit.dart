library;

import 'package:flutter/material.dart';

import 'layout.dart';
import 'surface.dart' show SurfaceRole;

enum SurfaceEdge {
  heavy,

  hairline,
}

@immutable
class MaterialKit {
  const MaterialKit({
    required this.radii,
    required this.slant,
    required this.edge,
    required this.activeFillIsAccent,
    required this.blur,
    required this.specularEdge,
    required this.castShadow,
    required this.transparentInactiveFill,
  });

  static const MaterialKit persona = MaterialKit(
    radii: _personaRadii,
    slant: true,
    edge: SurfaceEdge.heavy,
    activeFillIsAccent: true,
    blur: 0,
    specularEdge: false,
    castShadow: true,
    transparentInactiveFill: true,
  );

  static const Map<SurfaceRole, double> _personaRadii = {
    SurfaceRole.panel: 4.0,
    SurfaceRole.card: 4.0,
    SurfaceRole.bar: 4.0,
    SurfaceRole.sheet: 4.0,
  };

  static const MaterialKit solid = MaterialKit(
    radii: _plainRadii,
    slant: false,
    edge: SurfaceEdge.hairline,
    activeFillIsAccent: false,
    blur: 0,
    specularEdge: false,
    castShadow: false,
    transparentInactiveFill: false,
  );

  static const MaterialKit glass = MaterialKit(
    radii: _plainRadii,
    slant: false,
    edge: SurfaceEdge.hairline,
    activeFillIsAccent: false,
    blur: 24,
    specularEdge: true,
    castShadow: true,
    transparentInactiveFill: false,
  );

  static const Map<SurfaceRole, double> _plainRadii = {
    SurfaceRole.panel: 24.0,
    SurfaceRole.card: 24.0,
    SurfaceRole.bar: 26.0,
    SurfaceRole.sheet: 32.0,
  };

  final Map<SurfaceRole, double> radii;

  final bool slant;

  final SurfaceEdge edge;

  final bool activeFillIsAccent;

  final double blur;

  final bool specularEdge;

  final bool castShadow;

  final bool transparentInactiveFill;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialKit &&
          runtimeType == other.runtimeType &&
          slant == other.slant &&
          edge == other.edge &&
          activeFillIsAccent == other.activeFillIsAccent &&
          blur == other.blur &&
          specularEdge == other.specularEdge &&
          castShadow == other.castShadow &&
          transparentInactiveFill == other.transparentInactiveFill &&
          _radiiEqual(radii, other.radii);

  static bool _radiiEqual(Map<SurfaceRole, double> a, Map<SurfaceRole, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        slant,
        edge,
        activeFillIsAccent,
        blur,
        specularEdge,
        castShadow,
        transparentInactiveFill,

        Object.hashAllUnordered(
            radii.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

enum SectionBandForm {
  banner,

  mark,
}

enum TitleForm {
  stacked,

  beside,
}

enum HeaderForm {
  sectionBand,

  appHeader,
}

enum ShellFrame {
  docked,

  floating,
}

@immutable
class ChromeKit {
  const ChromeKit({
    required this.sectionBand,
    required this.libraryHeader,
    required this.shellFrame,
    required this.titleForm,

    required this.wordmark,
    required this.hemisphereScrim,
    required this.alfrescoCharacterArt,

    required this.artByDefault,
    required this.artReachBehindBars,
    required this.coverSize,
    required this.transportTilt,
    required this.scrubberBelowTransport,
    required this.backdropClip,
    required this.backdropReach,
    required this.upNextStrip,
    required this.panelSheetUsesSurface,
  });

  static const ChromeKit persona = ChromeKit(
    sectionBand: SectionBandForm.banner,
    libraryHeader: HeaderForm.sectionBand,

    titleForm: TitleForm.stacked,
    shellFrame: ShellFrame.docked,
    wordmark: true,
    hemisphereScrim: true,
    alfrescoCharacterArt: true,
    artByDefault: true,
    artReachBehindBars: 0,
    coverSize: 156,
    transportTilt: -0.038,
    scrubberBelowTransport: true,
    backdropClip: Clip.hardEdge,
    backdropReach: 0,
    upNextStrip: false,
    panelSheetUsesSurface: false,
  );

  static const ChromeKit plain = ChromeKit(
    sectionBand: SectionBandForm.mark,
    libraryHeader: HeaderForm.appHeader,

    titleForm: TitleForm.beside,
    shellFrame: ShellFrame.floating,
    wordmark: false,
    hemisphereScrim: false,
    alfrescoCharacterArt: false,
    artByDefault: false,

    artReachBehindBars: -88,
    coverSize: 88,
    transportTilt: 0,
    scrubberBelowTransport: false,
    backdropClip: Clip.none,
    backdropReach: -64,
    upNextStrip: true,
    panelSheetUsesSurface: true,
  );

  final bool artByDefault;

  final SectionBandForm sectionBand;
  final HeaderForm libraryHeader;
  final TitleForm titleForm;
  final ShellFrame shellFrame;

  final bool wordmark;

  final bool hemisphereScrim;

  final bool alfrescoCharacterArt;

  final double artReachBehindBars;

  final double coverSize;

  final double transportTilt;

  final bool scrubberBelowTransport;

  final Clip backdropClip;

  final double backdropReach;

  final bool upNextStrip;

  final bool panelSheetUsesSurface;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChromeKit &&
          runtimeType == other.runtimeType &&
          sectionBand == other.sectionBand &&
          libraryHeader == other.libraryHeader &&
          titleForm == other.titleForm &&
          shellFrame == other.shellFrame &&
          wordmark == other.wordmark &&
          hemisphereScrim == other.hemisphereScrim &&
          alfrescoCharacterArt == other.alfrescoCharacterArt &&
          artByDefault == other.artByDefault &&
          artReachBehindBars == other.artReachBehindBars &&
          coverSize == other.coverSize &&
          transportTilt == other.transportTilt &&
          scrubberBelowTransport == other.scrubberBelowTransport &&
          backdropClip == other.backdropClip &&
          backdropReach == other.backdropReach &&
          upNextStrip == other.upNextStrip &&
          panelSheetUsesSurface == other.panelSheetUsesSurface;

  @override
  int get hashCode => Object.hash(
        sectionBand,
        libraryHeader,
        titleForm,
        shellFrame,
        wordmark,
        hemisphereScrim,
        alfrescoCharacterArt,
        artByDefault,
        artReachBehindBars,
        coverSize,
        transportTilt,
        scrubberBelowTransport,
        backdropClip,
        backdropReach,
        upNextStrip,
        panelSheetUsesSurface,
      );
}

@immutable
class LayoutKit {
  const LayoutKit({
    required this.id,
    required this.displayName,
    required this.material,
    required this.motion,
    required this.arrangement,
    required this.chrome,
    this.palette,
    this.palettes = const [],
  });

  static const LayoutKit persona = LayoutKit(
    id: 'persona',
    displayName: 'PERSONA',
    material: MaterialKit.persona,
    motion: MotionSpec.persona,
    arrangement: ScreenLayout.persona,
    chrome: ChromeKit.persona,
  );

  final String id;
  final String displayName;

  final LayoutPalette? palette;

  final MaterialKit material;
  final MotionSpec motion;
  final ScreenLayout arrangement;
  final ChromeKit chrome;

  final List<NamedPalette> palettes;

  LayoutKit withPalette(LayoutPalette? palette) => LayoutKit(
        id: id,
        displayName: displayName,
        material: material,
        motion: motion,
        arrangement: arrangement,
        chrome: chrome,
        palette: palette,
        palettes: palettes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutKit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          palette == other.palette &&
          material == other.material &&
          motion == other.motion &&
          arrangement == other.arrangement &&
          chrome == other.chrome;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        palette,
        material,
        motion,
        arrangement,
        chrome,
      );
}

final LayoutKit kSolidKit = LayoutKit(
  id: 'solid',
  displayName: 'SOLID',
  material: MaterialKit.solid,
  motion: MotionSpec.restrained,
  arrangement: ScreenLayout.plain,
  chrome: ChromeKit.plain,
  palettes: kSolidPalettes,
);

final LayoutKit kGlassKit = LayoutKit(
  id: 'glass',
  displayName: 'GLASS',
  material: MaterialKit.glass,
  motion: MotionSpec.restrained,
  arrangement: ScreenLayout.plain,
  chrome: ChromeKit.plain,
  palettes: kGlassPalettes,
);
