library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../context/location_service.dart';
import '../context/place_icons.dart';
import '../context/places.dart';
import '../context/poi_service.dart';
import '../context/poi_types.dart';
import '../theme/layout.dart';
import '../theme/skin.dart';
import '../theme/slab.dart';
import '../widgets/pressable.dart';
import 'place_map.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({
    super.key,
    required this.skin,
    required this.places,
    required this.here,
    required this.poiService,
    this.kinds = const {},
    this.playlists = const [],
    this.inline = false,
    this.onChanged,
    this.onRefreshPosition,
  });

  final Skin skin;
  final PlaceBook places;

  final PlaceReading? here;

  final PoiService poiService;

  final Map<String, PoiKind> kinds;

  final List<String> playlists;

  final bool inline;

  final void Function(PlaceBook)? onChanged;

  final VoidCallback? onRefreshPosition;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  ({double lat, double lon})? _tapped;

  PoiResult? _lookup;
  bool _looking = false;

  late PlaceBook _book = widget.places;

  ({double lat, double lon})? get _target => _tapped ??
      (widget.here == null
          ? null
          : (lat: widget.here!.latitude, lon: widget.here!.longitude));

  Future<void> _askOverpass() async {
    final t = _target;
    if (t == null || _looking) return;
    setState(() => _looking = true);

    final r = await widget.poiService.lookup(latitude: t.lat, longitude: t.lon);
    if (!mounted) return;
    setState(() {
      _lookup = r;
      _looking = false;
    });
  }

  Future<void> _saveSpot() async {
    final t = _target;
    if (t == null) return;

    if (_lookup == null) await _askOverpass();
    if (!mounted) return;

    final kind = _lookup?.kind;
    final nameCtl = TextEditingController(text: kind?.label ?? _lookup?.name ?? '');
    final listCtl = TextEditingController(text: kind?.suggestedPlaylist ?? '');
    final radius = ValueNotifier<double>(
      kind != null && kind.mood == PoiMood.focus ? 400 : kDefaultPlaceRadiusM,
    );

    final iconCtl = ValueNotifier<String?>(_book.byId(_idFor(nameCtl.text.trim()))?.icon);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PresentationScope.uiSkin(context, widget.skin).background,
      builder: (ctx) => _NameSheet(
        skin: widget.skin,
        nameCtl: nameCtl,
        listCtl: listCtl,
        radius: radius,
        detected: _lookup,
        existingNames: [for (final p in _book.places) p.name],
        existingPlaylists: widget.playlists,
        icon: iconCtl,
      ),
    );

    if (saved != true || !mounted) return;

    final name = nameCtl.text.trim();
    if (name.isEmpty) return;
    final id = _idFor(name);

    final anchor = PlaceAnchor(
      latitude: t.lat,
      longitude: t.lon,
      radiusM: radius.value,
    );

    final existing = _book.byId(id);
    final next = existing == null
        ? _book.upsert(NamedPlace(
            id: id,
            name: name,
            anchors: [anchor],
            playlist: listCtl.text.trim().isEmpty ? null : listCtl.text.trim(),
            icon: iconCtl.value,
          ))
        : _book.withIcon(id, iconCtl.value).withAnchor(id, anchor);

    setState(() {
      _book = next;
      _tapped = null;
      _lookup = null;
    });
    widget.onChanged?.call(next);
  }

  Future<void> _editPlace(NamedPlace place) async {
    final nameCtl = TextEditingController(text: place.name);
    final listCtl = TextEditingController(text: place.playlist ?? '');
    final radius = ValueNotifier<double>(
      place.anchors.isEmpty ? kDefaultPlaceRadiusM : place.anchors.first.radiusM,
    );
    final iconCtl = ValueNotifier<String?>(place.icon);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PresentationScope.uiSkin(context, widget.skin).background,
      builder: (ctx) => _NameSheet(
        skin: widget.skin,
        nameCtl: nameCtl,
        listCtl: listCtl,
        radius: radius,
        detected: null,

        existingNames: [
          for (final p in _book.places)
            if (p.id != place.id) p.name,
        ],
        existingPlaylists: widget.playlists,
        icon: iconCtl,
        editing: true,
      ),
    );
    if (saved != true || !mounted) return;

    final name = nameCtl.text.trim();
    if (name.isEmpty) return;
    final newId = _idFor(name);

    final anchors = [
      for (final a in place.anchors)
        PlaceAnchor(latitude: a.latitude, longitude: a.longitude, radiusM: radius.value),
    ];

    setState(() {
      var next = newId == place.id ? _book : _book.remove(place.id);
      next = next.upsert(NamedPlace(
        id: newId,
        name: name,
        anchors: anchors,
        playlist: listCtl.text.trim().isEmpty ? null : listCtl.text.trim(),
        icon: iconCtl.value,
      ));
      _book = next;
    });
    widget.onChanged?.call(_book);
  }

  NamedPlace? get _hereInside {
    final here = widget.here;
    if (here == null) return null;
    for (final p in _book.places) {
      for (final a in p.anchors) {
        if (distanceMetres(
              lat1: here.latitude,
              lon1: here.longitude,
              lat2: a.latitude,
              lon2: a.longitude,
            ) <=
            a.radiusM) {
          return p;
        }
      }
    }
    return null;
  }

  String _idFor(String name) {
    final lower = name.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        buf.write(c);
      } else if (c == ' ' || c == '-' || c == '_') {
        buf.write('_');
      }
    }
    var id = buf.toString();
    while (id.contains('__')) {
      id = id.replaceAll('__', '_');
    }
    return id.replaceAll(RegExp(r'^_|_$'), '');
  }

  void _removePlace(String id) {
    final next = _book.remove(id);
    setState(() => _book = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final body = ListView(
      padding: widget.inline
          ? const EdgeInsets.fromLTRB(20, 8, 20, 24)
          : const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        if (!widget.inline) ...[
          ScreenTitle(skin: skin, text: 'PLACES'),
          const SizedBox(height: LayoutSpec.gapM),
        ],

        Row(
          children: [
            Expanded(
              child: NearestReadout(
                skin: skin,
                places: _book,
                here: widget.here,
              ),
            ),
            if (widget.onRefreshPosition != null)
              Pressable(
                child: InkWell(
                  onTap: widget.onRefreshPosition,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.my_location_rounded,
                        size: 18, color: skin.accent),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: LayoutSpec.gapM),

        PlaceMap(
          skin: skin,
          places: _book,
          overlays: widget.kinds,
          here: widget.here,
          initialCentre: _tapped == null
              ? null
              : LatLng(_tapped!.lat, _tapped!.lon),
          onTapPoint: (lat, lon) {
            setState(() {
              _tapped = (lat: lat, lon: lon);

              _lookup = null;
            });
          },
        ),
        const SizedBox(height: 6),
        MapAttribution(skin: skin),

        if (_tapped != null) ...[
          const SizedBox(height: 8),
          Text(
            'Tapped point selected — saving here, not where you stand',
            style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.accent),
          ),
        ],

        if (_hereInside != null) ...[
          const SizedBox(height: 8),
          Pressable(
            child: InkWell(
              onTap: () => _editPlace(_hereInside!),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(placeIconFor(_hereInside!.icon), size: 14, color: skin.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You are in ${_hereInside!.name} — tap to edit it',
                        style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: LayoutSpec.gapM),

        SaveSpotButton(
          skin: skin,
          here: widget.here,
          onSave: _saveSpot,
        ),

        if (_looking) ...[
          const SizedBox(height: 8),
          Text(

            'Asking OpenStreetMap what is here…',
            style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.textSecondary),
          ),
        ],

        if (_lookup != null && _lookup!.outcome == PoiLookup.none) ...[
          const SizedBox(height: 8),
          Text(

            'OpenStreetMap has nothing tagged here. Name it yourself.',
            style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.textSecondary),
          ),
        ],

        if (_lookup != null && _lookup!.outcome == PoiLookup.unavailable) ...[
          const SizedBox(height: 8),
          Text(

            'Could not reach OpenStreetMap — name it yourself.',
            style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.textSecondary),
          ),
        ],

        const SizedBox(height: 26),

        SectionLabel(
          skin: skin,
          text: 'SAVED PLACES',
          trailing: _book.isEmpty ? null : '${_book.length}',
        ),
        if (_book.isEmpty)
          Text(
            'Nothing saved yet. Stand somewhere, save a spot, and name it.',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
              height: 1.4,
            ),
          )
        else
          for (final p in _book.places) _placeTile(skin, p),
      ],
    );

    if (widget.inline) return body;
    return ColoredBox(
      color: PresentationScope.of(context, fallback: skin).palette.pageFill ??
              PresentationScope.of(context, fallback: skin).palette.background,
      child: SafeArea(child: body),
    );
  }

  Widget _placeTile(Skin skin, NamedPlace place) {
    final kind = widget.kinds[place.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slab(
        presentation: PresentationScope.of(context, fallback: skin),
        skin: skin,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: InkWell(

                onTap: () => _editPlace(place),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [

                      Icon(placeIconFor(place.icon),
                          size: 15, color: skin.accent),
                      const SizedBox(width: 7),
                      Text(
                        place.name,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontSmall,
                          fontWeight: FontWeight.w800,
                          color: skin.textPrimary,
                        ),
                      ),
                      if (kind != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: skin.accentAt(0.6)),
                          ),
                          child: Text(
                            kind.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: LayoutSpec.fontMicro,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w900,
                              color: skin.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(

                    '${place.anchors.length} '
                    '${place.anchors.length == 1 ? 'spot' : 'spots'}'
                    '${place.playlist != null ? ' · ${place.playlist}' : ''}',
                    style: TextStyle(
                      fontSize: LayoutSpec.fontLabel,
                      color: skin.textSecondary,
                    ),
                  ),
                ],
              ),
              ),
            ),

            Pressable(
              child: InkWell(
                onTap: () => _editPlace(place),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.edit_outlined,
                      size: 20, color: skin.textSecondary),
                ),
              ),
            ),
            Pressable(
              child: InkWell(
                onTap: () => _removePlace(place.id),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: skin.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({
    required this.skin,
    required this.nameCtl,
    required this.listCtl,
    required this.radius,
    required this.detected,
    required this.existingNames,
    required this.existingPlaylists,
    required this.icon,
    this.editing = false,
  });

  final bool editing;

  final Skin skin;

  final ValueNotifier<String?> icon;
  final TextEditingController nameCtl;
  final TextEditingController listCtl;
  final ValueNotifier<double> radius;
  final PoiResult? detected;
  final List<String> existingNames;

  final List<String> existingPlaylists;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final detected = widget.detected;
    final radius = widget.radius;
    final nameCtl = widget.nameCtl;
    final listCtl = widget.listCtl;
    final existingNames = widget.existingNames;
    final existingPlaylists = widget.existingPlaylists;
    final kind = detected?.kind;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedBuilder(
            animation: nameCtl,
            builder: (context, _) {
              final reuses = existingNames.any(
                (n) => n.toLowerCase() == nameCtl.text.trim().toLowerCase(),
              );
              if (!reuses || widget.editing) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'You already have a place by this name — saving adds this spot to it rather than '
                  'making a new one.',
                  style: TextStyle(fontSize: LayoutSpec.fontMicro, color: skin.accent),
                ),
              );
            },
          ),
          Text(
            widget.editing ? 'EDIT THIS PLACE' : 'NAME THIS SPOT',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
              color: skin.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kind != null

                ? 'OpenStreetMap says this is a ${kind.label.toLowerCase()}. '
                    'Change anything you like.'
                : 'Name it yourself — OpenStreetMap had nothing tagged here.',
            style: TextStyle(
              fontSize: LayoutSpec.fontLabel,
              color: skin.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          _field(skin, 'PLACE NAME', nameCtl,
              hint: 'e.g. University, Gym, Home'),
          const SizedBox(height: 12),

          if (existingPlaylists.isNotEmpty) ...[
            Text(
              'PLAYLIST HERE',
              style: TextStyle(
                fontSize: LayoutSpec.fontMicro,
                letterSpacing: 2,
                fontWeight: FontWeight.w800,
                color: skin.accent,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final name in existingPlaylists)
                  GestureDetector(
                    onTap: () {
                      listCtl.text = name;
                    },
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: listCtl,
                      builder: (context, v, _) {
                        final on = v.text.trim() == name;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: on ? skin.accent : Colors.transparent,
                            border: Border.all(
                              color: on
                                  ? skin.accent
                                  : skin.secondary(0.5),
                            ),
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: LayoutSpec.fontMicro,
                              fontWeight: FontWeight.w800,
                              color: on ? skin.onAccent : skin.textPrimary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          _field(skin, 'OR TYPE A NAME', listCtl,
              hint: kind?.suggestedPlaylist ?? 'e.g. Study'),
          const SizedBox(height: 16),

          Text(
            'ICON',
            style: TextStyle(
              fontSize: LayoutSpec.fontMicro,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: skin.accent,
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<String?>(
            valueListenable: widget.icon,
            builder: (context, chosen, _) => SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final entry in kPlaceIcons.entries)
                    Pressable(
                      child: InkWell(
                        onTap: () => widget.icon.value =
                            chosen == entry.key ? null : entry.key,
                        child: Container(
                          width: 46,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(

                            color: chosen == entry.key ? skin.accent : skin.panel,
                            border: Border.all(
                                color: chosen == entry.key
                                    ? skin.accent
                                    : skin.accentDeep),
                          ),
                          child: Icon(
                            entry.value,
                            size: 20,
                            color: chosen == entry.key
                                ? skin.onAccent
                                : skin.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(

            'Tap again to clear',
            style: TextStyle(color: skin.textSecondary, fontSize: LayoutSpec.fontMicro),
          ),
          const SizedBox(height: 16),

          Text(
            'HOW BIG IS THIS SPOT',
            style: TextStyle(
              fontSize: LayoutSpec.fontMicro,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              color: skin.accent,
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: radius,
            builder: (context, r, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: r,
                  min: 40,
                  max: 1500,
                  divisions: 29,
                  activeColor: skin.accent,
                  onChanged: (v) => radius.value = v,
                ),
                Text(

                  '${r.round()}m — about '
                  '${r < 120 ? 'one building' : r < 450 ? 'a building and its neighbours' : 'a campus'}',
                  style: TextStyle(
                    fontSize: LayoutSpec.fontMicro,
                    color: skin.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (existingNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(

              'Type an existing name (${existingNames.join(', ')}) to add this '
              'as another spot of that place.',
              style: TextStyle(
                fontSize: LayoutSpec.fontMicro,
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: skin.secondary(0.4)),
                      ),
                      child: Text(
                        'CANCEL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontMicro,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: skin.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Pressable(
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: skin.accent),
                      child: Text(
                        widget.editing ? 'SAVE CHANGES' : 'SAVE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: LayoutSpec.fontMicro,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: skin.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(
    Skin skin,
    String label,
    TextEditingController ctl, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: LayoutSpec.fontMicro,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: skin.accent,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctl,
          style: TextStyle(fontSize: 15, color: skin.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 15,
              color: skin.secondary(0.6),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            border: OutlineInputBorder(
              borderSide:
                  BorderSide(color: skin.secondary(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: skin.secondary(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: skin.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
