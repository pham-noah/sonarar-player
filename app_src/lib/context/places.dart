library;

import 'place_icons.dart';

import 'dart:convert';
import 'dart:io';

import '../context/location_service.dart';

class PlaceAnchor {
  const PlaceAnchor({
    required this.latitude,
    required this.longitude,
    this.radiusM = kDefaultPlaceRadiusM,
  });

  final double latitude;
  final double longitude;

  final double radiusM;

  bool contains(double lat, double lon) =>
      distanceMetres(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon) <=
      radiusM;

  Map<String, Object?> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'radius_m': radiusM,
      };

  static PlaceAnchor? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lon = raw['lon'];
    if (lat is! num || lon is! num) return null;
    final latD = lat.toDouble();
    final lonD = lon.toDouble();
    if (!latD.isFinite || !lonD.isFinite) return null;
    if (latD.abs() > 90 || lonD.abs() > 180) return null;

    if (latD == 0.0 && lonD == 0.0) return null;

    final r = (raw['radius_m'] as num?)?.toDouble() ?? kDefaultPlaceRadiusM;

    return PlaceAnchor(
      latitude: latD,
      longitude: lonD,
      radiusM: r.clamp(10.0, 5000.0),
    );
  }
}

class NamedPlace {
  const NamedPlace({
    required this.id,
    required this.name,
    required this.anchors,
    this.playlist,
    this.icon,
  });

  final String id;

  final String name;

  final List<PlaceAnchor> anchors;

  final String? playlist;

  final String? icon;
  bool get isUsable => anchors.isNotEmpty;

  double? distanceToNearest(double lat, double lon) {
    if (anchors.isEmpty) return null;
    var best = double.infinity;
    for (final a in anchors) {
      final d = distanceMetres(
        lat1: a.latitude,
        lon1: a.longitude,
        lat2: lat,
        lon2: lon,
      );
      if (d < best) best = d;
    }
    return best;
  }

  bool contains(double lat, double lon) {
    for (final a in anchors) {
      if (a.contains(lat, lon)) return true;
    }
    return false;
  }

  NamedPlace withIcon(String? newIcon) => NamedPlace(
        id: id,
        name: name,
        anchors: anchors,
        playlist: playlist,
        icon: newIcon,
      );

  NamedPlace withAnchor(PlaceAnchor anchor) => NamedPlace(
        id: id,
        name: name,
        anchors: [...anchors, anchor],
        playlist: playlist,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (playlist != null) 'playlist': playlist,
        if (icon != null) 'icon': icon,
        'anchors': [for (final a in anchors) a.toJson()],
      };

  static NamedPlace? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.trim().isEmpty) return null;
    final name = raw['name'];
    final anchorsRaw = raw['anchors'];
    if (anchorsRaw is! List) return null;

    final anchors = <PlaceAnchor>[];
    for (final a in anchorsRaw) {
      final parsed = PlaceAnchor.fromJson(a);
      if (parsed != null) anchors.add(parsed);
    }

    if (anchors.isEmpty) return null;

    final playlist = raw['playlist'];
    return NamedPlace(
      id: id.trim(),
      name: name is String && name.trim().isNotEmpty ? name.trim() : id.trim(),
      anchors: anchors,
      playlist: playlist is String && playlist.trim().isNotEmpty
          ? playlist.trim()
          : null,

      icon: isKnownPlaceIcon(raw['icon'] is String ? raw['icon'] as String : null)
          ? (raw['icon'] as String).trim()
          : null,
    );
  }
}

class PlaceBook {
  PlaceBook(List<NamedPlace> raw)
      : places = List<NamedPlace>.from(raw.where((p) => p.isUsable));

  static final PlaceBook empty = PlaceBook(const []);

  final List<NamedPlace> places;

  bool get isEmpty => places.isEmpty;
  int get length => places.length;

  NamedPlace? byId(String id) {
    for (final p in places) {
      if (p.id == id) return p;
    }
    return null;
  }

  NamedPlace? placeAt(double lat, double lon) {
    NamedPlace? best;
    var bestDistance = double.infinity;
    for (final p in places) {
      if (!p.contains(lat, lon)) continue;
      final d = p.distanceToNearest(lat, lon) ?? double.infinity;
      if (d < bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
    return best;
  }

  PlaceBook withIcon(String placeId, String? icon) {
    if (!places.any((p) => p.id == placeId)) return this;
    return PlaceBook([
      for (final p in places) p.id == placeId ? p.withIcon(icon) : p,
    ]);
  }

  PlaceBook withAnchor(String placeId, PlaceAnchor anchor) {
    final existing = byId(placeId);
    if (existing == null) return this;
    return PlaceBook([
      for (final p in places) p.id == placeId ? p.withAnchor(anchor) : p,
    ]);
  }

  PlaceBook upsert(NamedPlace place) {
    final out = <NamedPlace>[];
    var replaced = false;
    for (final p in places) {
      if (p.id == place.id) {
        out.add(place);
        replaced = true;
      } else {
        out.add(p);
      }
    }
    if (!replaced) out.add(place);
    return PlaceBook(out);
  }

  PlaceBook remove(String placeId) =>
      PlaceBook([for (final p in places) if (p.id != placeId) p]);

  String encode() => const JsonEncoder.withIndent('  ').convert({
        'places': [for (final p in places) p.toJson()],
      });

  static PlaceBook decode(String source) {
    try {
      final raw = jsonDecode(source);
      if (raw is! Map) return PlaceBook.empty;
      final list = raw['places'];
      if (list is! List) return PlaceBook.empty;
      final out = <NamedPlace>[];
      for (final item in list) {
        final p = NamedPlace.fromJson(item);
        if (p != null) out.add(p);
      }
      return PlaceBook(out);
    } on FormatException {
      return PlaceBook.empty;
    }
  }
}

class PlaceStore {
  PlaceStore(this.file);

  final File file;

  Future<PlaceBook> load() async {
    if (!file.existsSync()) return PlaceBook.empty;
    try {
      return PlaceBook.decode(await file.readAsString());
    } on FileSystemException {
      return PlaceBook.empty;
    }
  }

  Future<void> save(PlaceBook book) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(book.encode());
    } on FileSystemException {
      // ignore: empty_catches
    }
  }
}
