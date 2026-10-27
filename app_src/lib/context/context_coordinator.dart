library;

import 'dart:async';

import 'package:flutter/material.dart' show IconData;

import '../core/constants.dart';
import '../library/dynamic_playlist.dart';
import '../theme/skin_policy.dart';
import 'location_service.dart';
import 'place_icons.dart';
import 'place_refresh.dart';
import 'places.dart';
import 'poi_service.dart';
import 'poi_types.dart';
import 'weather_codes.dart';
import 'weather_cache.dart';
import 'weather_service.dart';

class ContextCoordinator {
  ContextCoordinator({
    required this.onChanged,
    required this.allowNetwork,
    required this.weatherEnabled,
  });

  final void Function() onChanged;

  final bool Function() allowNetwork;

  final bool Function() weatherEnabled;

  final WeatherService weather = WeatherService(timeout: kWeatherTimeout);
  final LocationService location = LocationService();
  final PoiService poi = PoiService();

  final SkinPolicy _policy = const SkinPolicy();

  final Map<String, PoiKind> _placeKinds = {};

  PlaceBook _placeBook = PlaceBook.empty;

  String? _currentPlaceId;

  PlaceReading? _place;

  PlaceReading? _lastPlaceFix;

  WeatherReading? _weather;

  Timer? _clock;
  Timer? _weatherTimer;

  PlaceBook get placeBook => _placeBook;
  String? get currentPlaceId => _currentPlaceId;
  PlaceReading? get place => _place;
  WeatherReading? get weatherReading => _weather;
  Map<String, PoiKind> get placeKinds => _placeKinds;
  bool get hasFix => _place != null;

  WeatherCondition get condition => _weather?.condition ?? WeatherCondition.unknown;

  bool get snowing => _weather?.condition == WeatherCondition.snow;

  NamedPlace? get currentPlace =>
      _currentPlaceId == null ? null : _placeBook.byId(_currentPlaceId!);

  String? get currentPlaceName => currentPlace?.name;

  IconData? get currentPlaceIcon => placeIconFor(currentPlace?.icon);

  bool get preciseFix =>
      _place != null && fixCanTellPlacesApart(_place!.source, _place!.accuracyMetres);

  ({double lat, double lon}) get weatherAt => _place == null
      ? (lat: kHomeLatitude, lon: kHomeLongitude)
      : (lat: _place!.latitude, lon: _place!.longitude);

  bool get commuting {
    if (_currentPlaceId != null) return false;
    if (_place == null) return false;
    final from = _lastPlaceFix;
    if (from == null) return false;
    return hasMoved(
      fromLat: from.latitude,
      fromLon: from.longitude,
      toLat: _place!.latitude,
      toLon: _place!.longitude,
    );
  }

  void startTimers({required Duration weatherRefresh}) {
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(weatherRefresh, (_) {
      if (allowNetwork() && weatherEnabled()) unawaited(refreshWeather());
    });
    _clock ??= Timer.periodic(const Duration(minutes: 1), (_) => onChanged());
  }

  void restartWeatherTimer(Duration weatherRefresh) {
    _weatherTimer?.cancel();
    _weatherTimer = Timer.periodic(weatherRefresh, (_) {
      if (allowNetwork() && weatherEnabled()) unawaited(refreshWeather());
    });
  }

  void dispose() {
    _clock?.cancel();
    _weatherTimer?.cancel();
    _clock = null;
    _weatherTimer = null;
    weather.dispose();
    poi.dispose();
    location.dispose();
  }

  void setPlaces(PlaceBook book) => _placeBook = book;

  PlayContext contextNow() {
    final now = DateTime.now();
    return PlayContext(
      band: _policy.bandFor(now.hour),

      sky: weatherEnabled() ? skyFrom(_weather?.condition) : Sky.unknown,
      whereabouts: whereaboutsNow(),
      localHour: now.hour,
      placeId: _currentPlaceId,
    );
  }

  Whereabouts whereaboutsNow() {
    final p = _place;
    if (p == null) return Whereabouts.unknown;
    if (_currentPlaceId != null) {
      return _currentPlaceId == 'home' ? Whereabouts.home : Whereabouts.atPlace;
    }
    final atHomeCoord = distanceMetres(
          lat1: p.latitude,
          lon1: p.longitude,
          lat2: kHomeLatitude,
          lon2: kHomeLongitude,
        ) <=
        kDefaultPlaceRadiusM;
    if (atHomeCoord) return Whereabouts.home;
    return commuting ? Whereabouts.commuting : Whereabouts.away;
  }

  Future<void> resolvePlaceThenWeather({Future<void> Function()? onArrival}) async {
    if (!allowNetwork()) {
      _place = null;
      _currentPlaceId = null;
      onChanged();
      return;
    }
    final place = await location.resolve();

    if (_place != null) _lastPlaceFix = _place;
    _place = place;

    final previousPlaceId = _currentPlaceId;
    _currentPlaceId = place == null
        ? null
        : _placeBook.placeAt(place.latitude, place.longitude)?.id;

    onChanged();

    final placeChanged = _currentPlaceId != previousPlaceId;
    if (placeChanged && place != null && fineEnough(place) && onArrival != null) {
      await onArrival();
    }

    if (place != null) unawaited(lookupKindFor(place));

    await refreshWeather();
  }

  bool fineEnough(PlaceReading r) => fixCanTellPlacesApart(r.source, r.accuracyMetres);

  Future<void> lookupKindFor(PlaceReading place) async {
    final id = _currentPlaceId;
    if (id == null) return;
    final result = await poi.lookup(
      latitude: place.latitude,
      longitude: place.longitude,
    );

    final kind = result.kind;
    if (kind != null) {
      _placeKinds[id] = kind;
      onChanged();
    }
  }

  Future<void> refreshWeather() async {
    if (!allowNetwork() || !weatherEnabled()) return;
    final at = weatherAt;
    final fetched = await weather.fetch(latitude: at.lat, longitude: at.lon);
    final resolved = resolveReading(
      cached: _weather,
      latitude: at.lat,
      longitude: at.lon,
      fetched: fetched,
      now: DateTime.now(),
    );

    final changed = _weather?.condition != resolved.condition;
    _weather = resolved;
    if (changed) onChanged();
  }

  void setPlaceId(String? id) {
    _currentPlaceId = id;
    onChanged();
  }
}
