library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide RepeatMode;

import '../theme/ambient_backdrop.dart';
import '../widgets/art_scrim.dart';
import '../widgets/cover_button.dart';
import '../widgets/pressable.dart';
import '../widgets/framed_art.dart';
import '../widgets/cross_fade_slot.dart';
import '../widgets/transport_motion.dart';

import '../context/context_icons.dart';
import '../context/place_icons.dart';
import '../context/weather_codes.dart';

import 'dart:io' show Directory;

import '../core/app_state.dart';
import '../core/constants.dart';
import '../library/variants.dart';
import '../art/skin_art.dart';
import '../library/track.dart';
import '../player/queue_mode.dart';
import '../player/queue.dart';
import '../theme/layout.dart';
import '../theme/layout_kit.dart';
import '../theme/motion.dart';
import '../theme/backdrop_layer.dart';
import '../theme/personalization.dart';
import '../theme/skin.dart';
import '../theme/skin_policy.dart';
import '../theme/surface.dart';
import '../widgets/stagger_in.dart';
import '../library/lyrics.dart';
import '../widgets/spectrum.dart';
import '../widgets/track_actions.dart';

enum PlayerPanel { none, why, queue, track, audio, loop }

const double kLyricsArtOpacity = 1.0;

const double kPlainArtBehind = 88.0;

class PlayerScreen extends StatelessWidget {
  static const Key lyricsButtonKey = Key('player-lyrics-button');

  const PlayerScreen({
    super.key,
    required this.state,
    required this.track,
    this.onPrevious,
    this.onNext,
    this.onPlayPause,
    this.onSeek,
    this.playing = false,
    this.fileMissing = false,
    this.panel = PlayerPanel.none,
    this.onPanel,
    this.onMinimise,
    this.panelMaximised = false,
    this.onPanelMaximised,
    this.whyContent,
    this.queueContent,
    this.audioContent,
    this.trackContent,
    this.loopContent,
    this.hasWhy = false,
    this.hasQueue = false,
    this.hasTrackPanel = false,
    this.upNextCount = 0,
    this.onSleep,
    this.stopAfterTrack = false,
    this.onStopAfterTrack,
    this.onArtist,
    this.lyricsMode = false,
    this.onLyrics,
    this.lyrics,

    this.romaji = const {},
    this.lyricsContent,
    this.sleepRunning = false,
    this.sleepTimer = const Duration(minutes: 45),
    this.spectrum,
    this.spectrumEase = 0.35,
    this.spectrumShape = SpectrumShape.rounded,

    this.spectrumHeight = LayoutSpec.spectrumHeight,
    this.sleepLeft,
    this.cover,
    this.shuffled = false,
    this.onShuffle,
    this.repeatMode = RepeatMode.off,
    this.onCycleRepeat,
    this.volume = 1.0,
    this.onVolume,
    this.onSwipeNext,
    this.onSwipePrevious,
    this.variants = const [],
    this.onSwapVariant,
    this.placeName,
    this.placeIcon,
    this.weather = WeatherCondition.unknown,
  });

  final AppState state;
  final Track? track;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPlayPause;

  final ValueChanged<Duration>? onSeek;

  final List<Track> variants;
  final ValueChanged<Track>? onSwapVariant;

  final String? placeName;

  final IconData? placeIcon;

  final WeatherCondition weather;
  final bool playing;

  final PlayerPanel panel;
  final ValueChanged<PlayerPanel>? onPanel;

  /// Leaving the player without the chevron: a downward swipe with no sheet
  /// open goes back to the tabs.
  final VoidCallback? onMinimise;

  final bool panelMaximised;
  final ValueChanged<bool>? onPanelMaximised;

  final Widget? whyContent;
  final Widget? queueContent;

  final Widget? audioContent;
  final Widget? trackContent;
  final Widget? loopContent;

  final bool hasWhy;
  final bool hasQueue;

  final bool hasTrackPanel;

  final int upNextCount;

  final ValueChanged<Duration?>? onSleep;

  final bool stopAfterTrack;

  final ValueChanged<bool>? onStopAfterTrack;

  final bool lyricsMode;

  final Lyrics? lyrics;

  final Map<int, String> romaji;

  final VoidCallback? onLyrics;

  final Widget? lyricsContent;

  final ValueChanged<String>? onArtist;

  final TrackSpectrum? spectrum;

  final double spectrumEase;

  final SpectrumShape spectrumShape;

  final double spectrumHeight;
  final bool sleepRunning;

  final Duration sleepTimer;

  final ValueNotifier<Duration?>? sleepLeft;

  final bool fileMissing;

  final ImageProvider? cover;

  final bool shuffled;
  final VoidCallback? onShuffle;
  final RepeatMode repeatMode;

  final double volume;
  final void Function(double)? onVolume;
  final VoidCallback? onCycleRepeat;

  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrevious;

  @override
  Widget build(BuildContext context) {
    final skin = state.uiSkin;
    final art = state.artForSurface(SurfaceId.player);
    final skew = skin.skewDegrees * (3.14159265 / 180);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: _swipeHorizontal,
      onVerticalDragEnd: lyricsMode ? null : _swipeVertical,
      child: _body(context, skin, art, skew),
    );
  }

  void _swipeHorizontal(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v > 220) {
      onSwipePrevious?.call();
    } else if (v < -220) {
      onSwipeNext?.call();
    }
  }

  /// Swiping the player up opens the queue; down puts it away. Changing the
  /// theme used to live here, which meant a careless swipe rewrote the theme
  /// you were wearing with no way to see it coming.
  void _swipeVertical(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -220) {
      onPanel?.call(PlayerPanel.queue);
    } else if (v > 220) {
      // Down means "put away": the sheet first, then the player itself. A
      // swipe that does nothing at all reads as a broken gesture.
      if (panel != PlayerPanel.none) {
        onPanel?.call(PlayerPanel.none);
      } else {
        onMinimise?.call();
      }
    }
  }

  Widget _body(BuildContext context, Skin skin, SkinArt? art, double skew) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    final showFigure =
        art != null &&
        (state.artChosen ||
            state.presentation.kit.chrome.artByDefault ||
            state.artSkinOverride != null);
    final chrome = state.presentation.kit.chrome;
    return Stack(
      fit: StackFit.expand,

      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: Motion.artCrossFade,
          curve: MotionCurve.art,
          color: pal.background,
        ),

        // The photo under the player's own art. When the backdrop asks for the
        // cover instead, this stays out of the way and the art does the work.
        if (state.personalization.backdropFor(SurfaceId.player).isSet &&
            !state.personalization.backdrop.coverOnPlayer)
          Positioned.fill(
            child: PersonalBackdrop(
              root: state.libraryRoot == null
                  ? null
                  : Directory(state.libraryRoot!),
              spec: state.personalization.backdropFor(SurfaceId.player),
              skin: skin,
            ),
          ),

        if (!state.personalization.backdropFor(SurfaceId.player).isSet &&
            state.personalization.fill.isSet)
          Positioned.fill(
            child: FillBackdrop(fill: state.personalization.fill),
          ),

        if (art != null && art.fullBleed && showFigure)
          Positioned.fill(
            child: CrossFadeSlot(
              keyValue: art.key,
              child: FramedArt(
                assetPath: art.assetPath,
                spec: art.spec,
                aspect: art.aspect,
                focus: state.artFocus,
                cacheWidth: 900,
                enterFrom: -220,
                burn: 1.0,
              ),
            ),
          ),

        if (art != null && !art.fullBleed && showFigure)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: chrome.artReachBehindBars,
            child: Builder(
              builder: (context) {
                final framed = CrossFadeSlot(
                  keyValue: art.key,
                  child: FramedArt(
                    assetPath: art.assetPath,
                    spec: art.spec,
                    aspect: art.aspect,
                    focus: state.artFocus,
                    cacheWidth: 900,
                    enterFrom: -220,
                    burn: 1.0,
                    opacity: lyricsMode ? kLyricsArtOpacity : 1.0,
                  ),
                );

                final placed = framed;
                if (lyricsMode) return placed;
                return ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => RadialGradient(
                    center: Alignment(
                      (state.artFocus.dx * 0.8).clamp(-1.0, 1.0) + 0.15,
                      (-state.artFocus.dy * 0.8).clamp(-1.0, 1.0) - 0.10,
                    ),
                    radius: 1.05,

                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.72),
                      Colors.transparent,
                    ],
                    stops: const [0.40, 0.66, 0.93],
                  ).createShader(rect),
                  child: placed,
                );
              },
            ),
          ),

        if (lyricsMode && lyricsContent != null) lyricsContent!,

        if (spectrum != null && !lyricsMode)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: spectrumHeight,
            child: ValueListenableBuilder<Duration>(
              valueListenable: state.position,
              builder: (context, at, _) => SpectrumBars(
                skin: skin,
                spectrum: spectrum,
                position: at,
                playing: playing,
                ease: spectrumEase,
                shape: spectrumShape,
              ),
            ),
          ),

        if (!lyricsMode && (chrome.hemisphereScrim || showFigure))
          Positioned.fill(child: ArtScrim(color: pal.background)),

        if (!lyricsMode)
          SafeArea(
            child: Padding(
              padding: LayoutSpec.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chrome.wordmark) ...[
                    _wordmark(skin, skew, pal),
                    const SizedBox(height: 4),
                    Text(
                      'NOW PLAYING',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 5,
                        fontWeight: FontWeight.w700,
                        color: pal.accent,
                      ),
                    ),
                  ],
                  if (state.arrangement.contextPlateExists) ...[
                    const SizedBox(height: 13),
                    _contextBadge(skin, skew, pal),
                    const SizedBox(height: 9),
                  ] else
                    const SizedBox(height: 9),
                  if (chrome.titleForm == TitleForm.stacked)
                    _meta(
                      context,
                      skin,
                      skew,
                      center: false,
                      titleBeside: false,
                      chrome: chrome,
                    ),
                  if (chrome.titleForm == TitleForm.beside) ...[
                    _upNext(skin, skew, showSourceLine: true),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              LayoutSpec.tabBarHeight +
                              state.arrangement.tabBarInsets.bottom +
                              (lyricsMode ? LayoutSpec.miniPlayerClearance : 0),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (lyrics != null && onLyrics != null)
                                  _liveLyricLine(context, skin),
                                _meta(
                                  context,
                                  skin,
                                  skew,
                                  center: false,
                                  titleBeside:
                                      chrome.titleForm == TitleForm.beside,
                                  chrome: chrome,
                                ),
                                const SizedBox(height: 12),
                                _controls(
                                  context,
                                  skin,
                                  skew,
                                  scrubberFirst: !chrome.scrubberBelowTransport,
                                  chrome: chrome,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _controls(
                            context,
                            skin,
                            skew,
                            scrubberFirst: !chrome.scrubberBelowTransport,
                            chrome: chrome,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

        if (panel != PlayerPanel.none) _panelOverlay(context, skin),
      ],
    );
  }

  Widget _wordmark(Skin skin, double skew, LayoutPalette pal) {
    return Row(
      children: [
        Text(
          'SONA',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: pal.textPrimary,
          ),
        ),
        Transform(
          transform: Matrix4.skewX(-skew),
          alignment: Alignment.center,
          child: Container(
            color: pal.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'R',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: pal.background,
              ),
            ),
          ),
        ),
        Text(
          'A R',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            color: pal.textPrimary,
          ),
        ),
      ],
    );
  }

  static const contextBadgeKey = Key('context-badge');

  static const transportKey = Key('player-transport');
  static const volumeKey = Key('player-volume');
  static const secondaryKey = Key('player-secondary');
  static const playButtonKey = Key('player-play');

  Widget _contextBadge(Skin skin, double skew, LayoutPalette pal) {
    return Transform(
      key: contextBadgeKey,
      transform: Matrix4.skewX(-skew),
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: skin.textPrimary,
          border: Border(left: BorderSide(color: skin.accentDeep, width: 5)),
          boxShadow: [
            BoxShadow(
              color: skin.slabShadow,
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),

        padding: const EdgeInsets.fromLTRB(13, 7, 14, 7),
        child: Transform(
          transform: Matrix4.skewX(skew),
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: skin.accentDeep,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      _contextLabel(skin),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: skin.background,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              GestureDetector(
                behavior: HitTestBehavior.opaque,

                onTap: state.contextEnabled ? state.toggleMode : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: state.contextEnabled
                          ? (state.mode == QueueMode.dynamic
                                ? 'Dynamic — the queue fills itself from the context. Tap for Fixed.'
                                : 'Fixed — only what you queued. Tap for Dynamic.')
                          : (state.mode == QueueMode.dynamic
                                ? 'Dynamic — the queue fills itself from the context.'
                                : 'Fixed — only what you queued.'),
                      child: _factChip(
                        skin,
                        skew,
                        state.mode == QueueMode.dynamic
                            ? Icons.auto_awesome_motion_rounded
                            : Icons.playlist_play_rounded,
                        dark: true,
                      ),
                    ),

                    if (state.mode == QueueMode.dynamic) ...[
                      const SizedBox(width: 5),
                      for (final fact in _contextFacts(skin))
                        Padding(
                          padding: const EdgeInsets.only(right: 5),
                          child: Tooltip(
                            message: fact.label,
                            child: _factChip(skin, skew, fact.icon),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _factChip(Skin skin, double skew, IconData icon, {bool dark = false}) {
    return Transform(
      transform: Matrix4.skewX(-skew * 2),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: dark ? skin.background : skin.accent,
          border: Border(
            left: BorderSide(
              color: dark ? skin.accent : skin.background,
              width: 2,
            ),
          ),
        ),
        child: Icon(icon, size: 14, color: skin.textPrimary),
      ),
    );
  }

  List<({IconData icon, String label})> _contextFacts(Skin skin) {
    final out = <({IconData icon, String label})>[];

    final sky = weatherIcon(weather);
    if (sky != null) out.add((icon: sky, label: weatherName(weather)));

    if (placeName != null && placeName!.trim().isNotEmpty) {
      out.add((icon: placeIcon ?? kDefaultPlaceIcon, label: placeName!));
    }
    return out;
  }

  String _contextLabel(Skin skin) {
    final ctx = state.playlistContext;
    if (ctx == null) return skin.contextLabel;
    return switch (ctx.band) {
      ContextBand.darkHour => skin.word(WordKey.bandDeepNight, 'NIGHT HOUR'),
      ContextBand.night => 'NIGHT',
      ContextBand.evening => 'EVENING',
      ContextBand.afternoon => 'AFTERNOON',
      ContextBand.morning => 'MORNING',
    };
  }

  Future<void> _pickVariant(
    BuildContext context,
    Skin skin,
    Track current,
  ) async {
    final pick = await showModalBottomSheet<Track>(
      context: context,
      showDragHandle: true,
      backgroundColor: skin.background,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'OTHER RECORDINGS',
                style: TextStyle(
                  color: skin.textSecondary,
                  fontSize: 12,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final v in variants)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: skin.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              v.variantTag == null
                                  ? 'ALBUM VERSION'
                                  : variantLabel(v.variantTag!),
                              style: TextStyle(
                                color: skin.accent,
                                fontSize: 12,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (v.id == current.id)
                        Icon(Icons.check_rounded, color: skin.accent, size: 20),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (pick != null) onSwapVariant?.call(pick);
  }

  Widget _meta(
    BuildContext context,
    Skin skin,
    double skew, {
    bool center = false,
    bool titleBeside = false,
    required ChromeKit chrome,
  }) {
    final t = track;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!titleBeside) ...[
          SwapSlide(
            keyValue: t?.id ?? '',
            child: Transform(
              transform: Matrix4.skewX(-skew * 0.6),
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      t?.title ?? 'Nothing loaded',

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.5,
                        color: skin.textPrimary,
                        shadows: const [
                          Shadow(
                            color: Color(0xE6000000),
                            blurRadius: 16,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (t != null && isKnownVariantTag(t.variantTag)) ...[
                    const SizedBox(width: 10),

                    Pressable(
                      child: InkWell(
                        onTap: (variants.isEmpty || onSwapVariant == null)
                            ? null
                            : () => _pickVariant(context, skin, t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: skin.accent,
                            border: Border.all(
                              color: skin.accentDeep,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                variantLabel(t.variantTag!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                  color: skin.onAccent,
                                ),
                              ),

                              if (variants.isNotEmpty &&
                                  onSwapVariant != null) ...[
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 14,
                                  color: skin.onAccent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          SwapSlide(
            keyValue: t?.id ?? '',
            stagger: const Duration(milliseconds: 60),
            child: Row(
              children: [
                Flexible(
                  child: GestureDetector(
                    onTap: (onArtist == null || (t?.artist ?? '').isEmpty)
                        ? null
                        : () => onArtist!(t!.artist),
                    child: Text(
                      t?.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: LayoutSpec.fontSmall,
                        fontWeight: FontWeight.w600,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Transform(
                  transform: Matrix4.skewX(-skew * 0.6),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(7, 1, 7, 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: skin.accentDeep.withValues(alpha: 0.6),
                      ),
                      color: skin.accentDeep.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      '0',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        fontWeight: FontWeight.w900,
                        color: skin.accentDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (cover != null || onPlayPause != null) ...[
          const SizedBox(height: 14),
          SwapSlide(
            keyValue: t?.id ?? '',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (t == null)
                  CoverButton(
                    skin: skin,
                    cover: cover,
                    playing: playing,
                    onPlayPause: onPlayPause,
                    size: chrome.coverSize,
                  )
                else
                  Hero(
                    tag: kCoverHeroTag(t.id),
                    child: CoverButton(
                      skin: skin,
                      cover: cover,
                      playing: playing,
                      onPlayPause: onPlayPause,
                      size: chrome.coverSize,
                    ),
                  ),
                if (titleBeside) ...[
                  const SizedBox(width: 14),
                  Flexible(child: _titleBeside(skin, t)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _titleBeside(Skin skin, Track? t) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t?.title ?? 'Nothing loaded',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          height: 1.05,
          letterSpacing: -0.5,
          color: skin.textPrimary,
          shadows: const [
            Shadow(
              color: Color(0xE6000000),
              blurRadius: 16,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
      if (t != null && t.artist.trim().isNotEmpty) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: (onArtist == null || (t.artist).isEmpty)
              ? null
              : () => onArtist!(t.artist),
          behavior: HitTestBehavior.opaque,
          child: Text(
            t.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontSmall,
              fontWeight: FontWeight.w600,

              color: skin.textPrimary,
              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  Widget _transportRow(Skin skin, double skew) => StaggerIn(
    index: 0,
    style: StaggerStyle.rise,

    child: FittedBox(
      key: transportKey,
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _transportButton(
            skin,
            skew,
            Icons.shuffle_rounded,
            onTap: onShuffle,
            active: shuffled,
            compact: true,
          ),
          const SizedBox(width: 7),
          NudgingButton(
            direction: -1,
            onTap: onPrevious,
            child: _transportButton(
              skin,
              skew,
              Icons.skip_previous_rounded,
              onTap: onPrevious,
            ),
          ),
          const SizedBox(width: 8),
          _playButton(skin, skew, playing: playing),
          const SizedBox(width: 8),
          NudgingButton(
            direction: 1,
            onTap: onNext,
            child: _transportButton(
              skin,
              skew,
              Icons.skip_next_rounded,
              onTap: onNext,
            ),
          ),
          const SizedBox(width: 10),
          _transportButton(
            skin,
            skew,
            _repeatIcon(repeatMode),
            onTap: onCycleRepeat,
            active: repeatMode != RepeatMode.off,
            compact: true,
          ),
        ],
      ),
    ),
  );

  Widget _controls(
    BuildContext context,
    Skin skin,
    double skew, {
    required bool scrubberFirst,
    required ChromeKit chrome,
  }) {
    final block = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (scrubberFirst) ...[
          _progressBar(skin, skew),
          const SizedBox(height: 6),
          _times(skin, skew),
          const SizedBox(height: 14),
        ],
        if (chrome.wordmark) ...[
          _progressBar(skin, skew),
          const SizedBox(height: 10),
          _times(skin, skew),
          const SizedBox(height: 14),
        ],
        _transportRow(skin, skew),

        const SizedBox(height: 12),
        StaggerIn(
          index: 2,
          style: StaggerStyle.rise,

          overrideDx: -210,
          overrideDy: 26,
          child: TrackActions(
            skin: skin,
            audioOpen: panel == PlayerPanel.audio,
            onAudio: audioContent == null
                ? null
                : () => onPanel?.call(
                    panel == PlayerPanel.audio
                        ? PlayerPanel.none
                        : PlayerPanel.audio,
                  ),

            actions: [
              if (hasWhy)
                _iconAction(
                  skin,
                  Icons.help_outline_rounded,
                  'Why this song',
                  () => onPanel?.call(
                    panel == PlayerPanel.why
                        ? PlayerPanel.none
                        : PlayerPanel.why,
                  ),
                  active: panel == PlayerPanel.why,
                ),
              if (hasQueue)
                _iconAction(
                  skin,
                  Icons.queue_music_rounded,
                  upNextCount == 0 ? 'Queue' : 'Queue ($upNextCount)',
                  () => onPanel?.call(
                    panel == PlayerPanel.queue
                        ? PlayerPanel.none
                        : PlayerPanel.queue,
                  ),
                  active: panel == PlayerPanel.queue,
                  badge: upNextCount > 0 ? '$upNextCount' : null,
                ),

              if (hasTrackPanel)
                _iconAction(
                  skin,
                  Icons.tune_rounded,
                  'This track — bookmark, tags, loop points',
                  () => onPanel?.call(
                    panel == PlayerPanel.track
                        ? PlayerPanel.none
                        : PlayerPanel.track,
                  ),
                  active: panel == PlayerPanel.track,
                ),
              if (onStopAfterTrack != null)
                _iconAction(
                  skin,
                  stopAfterTrack
                      ? Icons.stop_circle_rounded
                      : Icons.stop_circle_outlined,
                  stopAfterTrack
                      ? 'Stopping after this track — tap to cancel'
                      : 'Stop after this track',
                  () => onStopAfterTrack!(!stopAfterTrack),
                  active: stopAfterTrack,
                ),
              if (onSleep != null)
                _iconAction(
                  skin,
                  sleepRunning ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                  sleepRunning
                      ? 'Sleep timer on — tap to turn off'
                      : 'Sleep timer',
                  () => onSleep!(sleepRunning ? null : sleepTimer),
                  active: sleepRunning,
                ),
            ],
          ),
        ),

        if (sleepLeft != null)
          ValueListenableBuilder<Duration?>(
            valueListenable: sleepLeft!,
            builder: (context, left, _) {
              if (left == null) return const SizedBox.shrink();
              final total = left.inSeconds;
              final h = total ~/ 3600;
              final m = (total % 3600) ~/ 60;
              final sec = total % 60;
              final text = h > 0
                  ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
                  : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bedtime_rounded, size: 14, color: skin.accent),
                    const SizedBox(width: 6),
                    Text(
                      'SLEEP IN $text',
                      style: TextStyle(
                        fontSize: LayoutSpec.fontLabel,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                        color: skin.accent,

                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        const SizedBox(height: 14),
        if (chrome.titleForm == TitleForm.stacked)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onLyrics != null) ...[
                _lyricsButton(skin),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _upNext(skin, skew, showSourceLine: chrome.upNextStrip),
              ),
            ],
          ),

        if (fileMissing)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Track file not found on this device',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                fontWeight: FontWeight.w700,
                color: skin.accent,
              ),
            ),
          ),
      ],
    );
    return chrome.transportTilt == 0
        ? block
        : Transform.rotate(angle: chrome.transportTilt, child: block);
  }

  Widget _liveLyricLine(BuildContext context, Skin skin) {
    final pal = PresentationScope.of(context, fallback: skin).palette;
    return ValueListenableBuilder<Duration>(
      valueListenable: state.position,
      builder: (context, at, _) {
        final l = lyrics;
        if (l == null) return const SizedBox.shrink();
        final i = l.indexAt(at);
        final text = (i >= 0 && i < l.lines.length)
            ? (romaji[i] ?? l.lines[i].text)
            : null;
        final has = text != null && text.trim().isNotEmpty;
        return GestureDetector(
          onTap: has ? onLyrics : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              has ? text : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: LayoutSpec.fontSmall,
                fontWeight: FontWeight.w600,

                color: has
                    ? pal.textPrimary
                    : pal.textSecondary.withValues(alpha: 0.5),
                shadows: const [
                  Shadow(
                    color: Color(0xCC000000),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _panelOverlay(BuildContext context, Skin skin) {
    final chrome = state.presentation.kit.chrome;
    final content = switch (panel) {
      PlayerPanel.why => whyContent,
      PlayerPanel.queue => queueContent,
      PlayerPanel.audio => audioContent,
      PlayerPanel.track => trackContent,
      PlayerPanel.loop => loopContent,
      PlayerPanel.none => null,
    };
    if (content == null) return const SizedBox.shrink();

    final title = switch (panel) {
      PlayerPanel.why => 'WHY THIS SONG',
      PlayerPanel.queue => 'QUEUE',
      PlayerPanel.audio => 'AUDIO',
      PlayerPanel.track => 'THIS TRACK',
      PlayerPanel.loop => 'LOOP POINTS',
      PlayerPanel.none => '',
    };

    var dragDy = 0.0;
    // A list at its top has no more room to scroll, so a downward flick there
    // arrives as overscroll. Without this, the sheet can only be dragged by
    // its header and swiping down over the queue looks broken.
    var pull = 0.0;

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => onPanel?.call(PlayerPanel.none),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Clear the gesture pill / nav bar: the sheet is anchored to the
              // very bottom of the screen and its last row would sit under it.
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: GestureDetector(
              onVerticalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                final dy = dragDy;
                dragDy = 0;
                if (v < -220 || dy < -48) {
                  onPanelMaximised?.call(true);
                } else if (v > 220 || dy > 48) {
                  if (panelMaximised) {
                    onPanelMaximised?.call(false);
                  } else {
                    onPanel?.call(PlayerPanel.none);
                  }
                }
              },
              onVerticalDragUpdate: (d) => dragDy += d.primaryDelta ?? 0,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is OverscrollNotification && n.overscroll < 0) {
                    pull += -n.overscroll;
                  } else if (n is ScrollEndNotification) {
                    final pulled = pull;
                    pull = 0;
                    if (pulled > 90) {
                      if (panelMaximised) {
                        onPanelMaximised?.call(false);
                      } else {
                        onPanel?.call(PlayerPanel.none);
                      }
                    }
                  }
                  return false;
                },
                child: Builder(
                builder: (context) {
                  final layout = PresentationScope.of(context, fallback: skin);
                  final sheet = SizedBox(
                    height: panelMaximised
                        ? MediaQuery.of(context).size.height
                        : MediaQuery.of(context).size.height * 0.64,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(
                              Icons.drag_handle_rounded,
                              color: skin.textSecondary,
                            ),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: LayoutSpec.fontLabel,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w800,
                                  color: skin.accent,
                                ),
                              ),
                            ),
                            if (panelMaximised)
                              IconButton(
                                onPressed: () => onPanelMaximised?.call(false),
                                icon: Icon(
                                  Icons.fullscreen_exit_rounded,
                                  color: skin.textPrimary,
                                  size: 26,
                                ),
                                tooltip: 'Shrink',
                              ),
                            IconButton(
                              onPressed: () => onPanel?.call(PlayerPanel.none),
                              icon: Icon(
                                Icons.close_rounded,
                                color: skin.textPrimary,
                                size: 28,
                              ),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        Expanded(child: content),
                      ],
                    ),
                  );
                  if (!chrome.panelSheetUsesSurface) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: skin.background,
                        border: Border(
                          top: BorderSide(color: skin.accent, width: 2),
                        ),
                      ),
                      child: sheet,
                    );
                  }
                  return Surface(
                    presentation: layout,
                    role: SurfaceRole.panel,
                    radius: 20,
                    accentEdge: false,
                    child: sheet,
                  );
                },
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(
    Skin skin,
    IconData icon,
    String tooltip,
    VoidCallback onTap, {
    bool active = false,
    String? badge,
  }) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        child: InkWell(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 42,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? skin.accent : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? skin.accent
                        : skin.secondary(0.42),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? skin.onAccent : skin.textSecondary,
                ),
              ),

              if (badge != null)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: skin.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: skin.onAccent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lyricsButton(Skin skin) {
    final active = lyricsMode;
    return Pressable(
      child: GestureDetector(
        key: lyricsButtonKey,
        onTap: onLyrics,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? skin.accent : Colors.transparent,
            border: Border.all(
              color: active
                  ? skin.accent
                  : skin.secondary(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lyrics_outlined,
                size: 16,
                color: active ? skin.onAccent : skin.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                'LYRICS',
                style: TextStyle(
                  fontSize: LayoutSpec.fontLabel,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: active ? skin.onAccent : skin.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upNext(Skin skin, double skew, {bool showSourceLine = false}) {
    final q = state.queue;
    final upcoming = q?.upcoming ?? const [];
    final nextTitle = upcoming.isEmpty ? null : upcoming.first.title;
    final nextArtist = upcoming.isEmpty ? null : upcoming.first.artist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSourceLine && state.playingFrom != null) ...[
          Text(
            'Playing from ${state.playingFrom}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              letterSpacing: 0.4,
              color: skin.textSecondary,

              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(height: 1, color: skin.accentAt(0.2)),
        const SizedBox(height: 11),
        Transform(
          transform: Matrix4.skewX(-skew),
          alignment: Alignment.centerLeft,
          child: Text(
            nextTitle == null ? 'END OF QUEUE' : 'UP NEXT',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              color: skin.accent,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          nextTitle ?? 'Nothing after this',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: skin.textPrimary,
            shadows: const [
              Shadow(
                color: Color(0xE6000000),
                blurRadius: 14,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        if (nextArtist != null) ...[
          const SizedBox(height: 2),
          Text(
            nextArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: LayoutSpec.fontSmall,
              fontWeight: FontWeight.w600,

              color: skin.textPrimary,
              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 12,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _progressBar(Skin skin, double skew) => PlayerProgressBar(
    skin: skin,
    skew: skew,
    position: state.position,
    duration: state.duration,
    onSeek: onSeek,
  );

  Widget _times(Skin skin, double skew) {
    return Transform(
      transform: Matrix4.skewX(-skew),
      alignment: Alignment.centerLeft,

      child: ValueListenableBuilder<Duration>(
        valueListenable: state.position,
        builder: (context, pos, _) => ValueListenableBuilder<Duration?>(
          valueListenable: state.duration,
          builder: (context, dur, __) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform(
                transform: Matrix4.skewX(skew),
                child: Text(_clock(pos), style: _timeStyle(skin)),
              ),
              Transform(
                transform: Matrix4.skewX(skew),
                child: Text(
                  dur == null ? '--:--' : _clock(dur),
                  style: _timeStyle(skin),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final sec = d.inSeconds.remainder(60);
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  TextStyle _timeStyle(Skin skin) => TextStyle(
    fontSize: LayoutSpec.fontSmall,
    fontWeight: FontWeight.w700,
    color: skin.textSecondary,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  Widget _transportButton(
    Skin skin,
    double skew,
    IconData icon, {
    VoidCallback? onTap,
    bool active = false,
    bool compact = false,
  }) {
    final w = compact ? 44.0 : LayoutSpec.transportButtonWidth;
    return Pressable(
      child: Transform(
        transform: Matrix4.skewX(-skew),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: w,
            height: LayoutSpec.transportButtonHeight,
            decoration: BoxDecoration(
              color: active ? skin.accent : skin.panel,
              border: Border.all(
                color: active
                    ? skin.accent
                    : skin.accentAt(0.55),
                width: 1.5,
              ),
            ),
            child: Transform(
              transform: Matrix4.skewX(skew),
              child: Icon(
                icon,
                size: compact ? 18 : 21,
                color: active ? skin.onAccent : skin.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _repeatIcon(RepeatMode mode) => switch (mode) {
    RepeatMode.off => Icons.repeat_rounded,
    RepeatMode.all => Icons.repeat_rounded,
    RepeatMode.one => Icons.repeat_one_rounded,
  };

  Widget _playButton(Skin skin, double skew, {required bool playing}) {
    return Pressable(
      child: Transform(
        transform: Matrix4.skewX(-skew),
        child: InkWell(
          onTap: onPlayPause,
          child: PopOnChange(
            keyValue: playing,
            child: Container(
              width: LayoutSpec.playButtonWidth,
              height: LayoutSpec.playButtonHeight,
              decoration: BoxDecoration(
                color: skin.textPrimary,
                boxShadow: [
                  BoxShadow(
                    color: skin.accentAt(0.42),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Transform(
                transform: Matrix4.skewX(skew),
                child: AnimatedSwitcher(
                  duration: Motion.morph,
                  switchInCurve: MotionCurve.morph,
                  switchOutCurve: MotionCurve.morph,

                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(playing),
                    size: 30,
                    color: skin.background,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.skin,
    required this.skew,
    required this.position,
    required this.duration,
    this.onSeek,
  });

  final Skin skin;
  final double skew;
  final ValueListenable<Duration> position;
  final ValueListenable<Duration?> duration;
  final ValueChanged<Duration>? onSeek;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar> {
  double? _dragFrac;

  void _seekTo(double dx, double width, Duration? dur, {bool remember = true}) {
    if (dur == null || dur.inMilliseconds <= 0 || width <= 0) return;
    final f = (dx / width).clamp(0.0, 1.0);

    // Only a drag pins the bar; a tap used to pin it and nothing cleared it.
    if (remember) {
      setState(() => _dragFrac = f);
    }
    widget.onSeek?.call(
      Duration(milliseconds: (dur.inMilliseconds * f).round()),
    );
  }

  static double _fraction(Duration pos, Duration? dur) {
    if (dur == null || dur.inMilliseconds <= 0) return 0;
    final f = pos.inMilliseconds / dur.inMilliseconds;
    return f.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final skew = widget.skew;
    return Transform(
      transform: Matrix4.skewX(-skew),
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 26,
        child: LayoutBuilder(
          builder: (context, box) => ValueListenableBuilder<Duration>(
            valueListenable: widget.position,
            builder: (context, pos, _) => ValueListenableBuilder<Duration?>(
              valueListenable: widget.duration,
              builder: (context, dur, __) {
                final frac = _dragFrac ?? _fraction(pos, dur);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _seekTo(
                    d.localPosition.dx,
                    box.maxWidth,
                    dur,
                    remember: false,
                  ),
                  onHorizontalDragStart: (d) =>
                      _seekTo(d.localPosition.dx, box.maxWidth, dur),
                  onHorizontalDragUpdate: (d) =>
                      _seekTo(d.localPosition.dx, box.maxWidth, dur),

                  onHorizontalDragEnd: (_) => setState(() => _dragFrac = null),
                  onHorizontalDragCancel: () =>
                      setState(() => _dragFrac = null),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: ColoredBox(
                            color: skin.secondary(0.26),
                            child: const SizedBox(
                              height: 7,
                              width: double.infinity,
                            ),
                          ),
                        ),
                      ),

                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: frac,
                            child: SizedBox(
                              height: 7,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [skin.accentDeep, skin.accent],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned(
                        left: (box.maxWidth * frac - 7).clamp(
                          0.0,
                          box.maxWidth - 14,
                        ),
                        child: Transform(
                          transform: Matrix4.skewX(skew),
                          child: AnimatedContainer(
                            duration: Motion.morph,
                            curve: MotionCurve.morph,
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: skin.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: skin.accent.withValues(
                                    alpha: 0.35 + 0.35 * frac,
                                  ),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
