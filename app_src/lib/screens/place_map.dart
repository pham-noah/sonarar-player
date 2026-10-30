library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../context/location_service.dart';
import '../context/places.dart';
import '../context/poi_types.dart';
import '../theme/motion.dart';
import '../theme/skin.dart';

class PlaceOverlay {
  const PlaceOverlay({required this.place, this.kind});

  final NamedPlace place;

  final PoiKind? kind;
}

class PlaceMap extends StatelessWidget {
  const PlaceMap({
    super.key,
    required this.skin,
    required this.places,
    required this.overlays,
    this.here,
    this.onTapPoint,
    this.initialCentre,
    this.height = 320,
  });

  final Skin skin;

  final PlaceBook places;

  final Map<String, PoiKind> overlays;

  final PlaceReading? here;

  final void Function(double lat, double lon)? onTapPoint;

  final LatLng? initialCentre;

  final double height;

  LatLng get _centre {
    if (initialCentre != null) return initialCentre!;
    if (here != null) return LatLng(here!.latitude, here!.longitude);
    if (places.places.isNotEmpty) {
      final a = places.places.first.anchors.first;
      return LatLng(a.latitude, a.longitude);
    }

    return const LatLng(20, 0);
  }

  double get _zoom => here != null || places.places.isNotEmpty ? 15.0 : 1.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRect(
        child: FlutterMap(
          options: MapOptions(
            initialCenter: _centre,
            initialZoom: _zoom,

            onTap: onTapPoint == null
                ? null
                : (tap, point) => onTapPoint!(point.latitude, point.longitude),

            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

              userAgentPackageName: 'com.noah.personar',

              maxNativeZoom: 19,
            ),

            CircleLayer(
              circles: [
                for (final p in places.places)
                  for (final a in p.anchors)
                    CircleMarker(
                      point: LatLng(a.latitude, a.longitude),

                      radius: a.radiusM,
                      useRadiusInMeter: true,
                      color: _tint(p).withValues(alpha: 0.18),
                      borderColor: _tint(p).withValues(alpha: 0.85),
                      borderStrokeWidth: 1.5,
                    ),
              ],
            ),

            MarkerLayer(
              markers: [
                for (final p in places.places)
                  for (final a in p.anchors)
                    Marker(
                      point: LatLng(a.latitude, a.longitude),
                      width: 84,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: _placePin(p),
                    ),

                if (here != null)
                  Marker(
                    point: LatLng(here!.latitude, here!.longitude),
                    width: 26,
                    height: 26,
                    child: _hereDot(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _tint(NamedPlace place) {
    final kind = overlays[place.id];
    if (kind == null) return skin.accent;
    return switch (kind.mood) {
      PoiMood.focus => const Color(0xFF4A9EFF),
      PoiMood.energy => const Color(0xFFFF6B35),
      PoiMood.social => const Color(0xFFE3B84E),
      PoiMood.transit => const Color(0xFF9B7EDE),
      PoiMood.quiet => const Color(0xFF57C4A6),
      PoiMood.any => skin.accent,
    };
  }

  Widget _placePin(NamedPlace place) {
    final colour = _tint(place);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: skin.background.withValues(alpha: 0.85),
            border: Border.all(color: colour, width: 1.5),
          ),
          child: Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: skin.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Icon(Icons.place_rounded, size: 18, color: colour),
      ],
    );
  }

  Widget _hereDot() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7DFF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 6),
        ],
      ),
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.skin});

  final Skin skin;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Map data © OpenStreetMap contributors',
      style: TextStyle(
        fontSize: 12,
        color: skin.secondary(0.8),
      ),
    );
  }
}

class NearestReadout extends StatelessWidget {
  const NearestReadout({
    super.key,
    required this.skin,
    required this.places,
    required this.here,
  });

  final Skin skin;
  final PlaceBook places;
  final PlaceReading? here;

  @override
  Widget build(BuildContext context) {
    final pos = here;
    if (pos == null) {
      return Text(

        'Position not known yet',
        style: TextStyle(fontSize: 12, color: skin.textSecondary),
      );
    }

    final inside = places.placeAt(pos.latitude, pos.longitude);
    if (inside != null) {
      final d = inside.distanceToNearest(pos.latitude, pos.longitude) ?? 0;
      return Text(
        'At ${inside.name} · ${d.round()}m from its nearest spot'
        '${pos.accuracyMetres != null ? ' · ±${pos.accuracyMetres!.round()}m' : ''}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: skin.accent,
        ),
      );
    }

    if (places.isEmpty) {
      return Text(
        'No places saved yet',
        style: TextStyle(fontSize: 12, color: skin.textSecondary),
      );
    }

    var bestName = '';
    var bestDistance = double.infinity;
    for (final p in places.places) {
      final d = p.distanceToNearest(pos.latitude, pos.longitude) ?? double.infinity;

      final edge = d - (p.anchors.first.radiusM);
      if (edge < bestDistance) {
        bestDistance = edge;
        bestName = p.name;
      }
    }

    return Text(
      'Not in a saved place · nearest is $bestName, '
      '${bestDistance.round()}m away',
      style: TextStyle(fontSize: 12, color: skin.textSecondary),
    );
  }
}

class SaveSpotButton extends StatelessWidget {
  const SaveSpotButton({
    super.key,
    required this.skin,
    required this.onSave,
    this.here,
    this.accuracyLimitM = 100,
  });

  final Skin skin;
  final VoidCallback onSave;
  final PlaceReading? here;

  final double accuracyLimitM;

  bool get _usable {
    final h = here;
    if (h == null) return false;
    final a = h.accuracyMetres;

    return a == null || a <= accuracyLimitM;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _usable ? onSave : null,
          child: AnimatedContainer(
            duration: Motion.morph,
            curve: MotionCurve.morph,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _usable ? skin.accent : skin.panel,
              border: Border.all(
                color: _usable
                    ? skin.accent
                    : skin.secondary(0.4),
              ),
            ),
            child: Text(
              _usable ? 'SAVE THIS SPOT' : 'WAITING FOR A GOOD FIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: _usable ? skin.onAccent : skin.textSecondary,
              ),
            ),
          ),
        ),
        if (!_usable) ...[
          const SizedBox(height: 4),
          Text(

            'Stand still a moment — the position is only good to '
            '±${here?.accuracyMetres?.round() ?? '?'}m',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: skin.textSecondary),
          ),
        ],
      ],
    );
  }
}
