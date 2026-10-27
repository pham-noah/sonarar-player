library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/context/place_icons.dart';
import 'package:sonarar/context/places.dart';

NamedPlace _place({String? icon}) => NamedPlace(
      id: 'uni',
      name: 'University',
      anchors: const [
        PlaceAnchor(latitude: 60.2, longitude: 24.9, radiusM: 400),
      ],
      icon: icon,
    );

void main() {
  group('placeIconFor is total', () {
    test('no icon gives the default, not a blank', () {
      expect(placeIconFor(null), kDefaultPlaceIcon);
    });

    test('every known name resolves to a real icon', () {
      for (final name in kPlaceIcons.keys) {
        expect(placeIconFor(name), kPlaceIcons[name], reason: name);
      }
    });

    test('an UNKNOWN name falls back rather than rendering nothing', () {
      expect(isKnownPlaceIcon('hovercraft'), isFalse);
      expect(placeIconFor('hovercraft'), kDefaultPlaceIcon);
    });

    test('the default is a pin, because every place is somewhere', () {
      expect(kDefaultPlaceIcon, Icons.place_rounded);
    });

    test('labels come from the stable name', () {
      expect(placeIconLabel('home'), 'Home');
      expect(placeIconLabel('gym'), 'Gym');
    });
  });

  group('a place round-trips its icon through disk', () {
    test('a known icon survives encode and decode', () {
      final saved = _place(icon: 'school');
      final back = NamedPlace.fromJson(saved.toJson());
      expect(back, isNotNull);
      expect(back!.icon, 'school');
    });

    test('no icon stays null rather than becoming a string', () {
      final back = NamedPlace.fromJson(_place().toJson());
      expect(back!.icon, isNull);
    });

    test('an unknown icon on disk is DROPPED, not carried and not fatal', () {
      final json = _place(icon: 'school').toJson();
      json['icon'] = 'hovercraft';
      final back = NamedPlace.fromJson(json);
      expect(back, isNotNull);
      expect(back!.icon, isNull);
      expect(back.name, 'University', reason: 'the place itself is kept');
    });
  });

  group('changing the icon', () {
    test('withIcon replaces it', () {
      expect(_place(icon: 'home').withIcon('gym').icon, 'gym');
    });

    test('withIcon can CLEAR it, which is how a wrong choice is undone', () {
      expect(_place(icon: 'home').withIcon(null).icon, isNull);
    });

    test('changing the icon keeps everything else about the place', () {
      final before = _place(icon: 'home').toJson()..remove('icon');
      final after = _place(icon: 'home').withIcon('gym').toJson()..remove('icon');
      expect(after, before);
    });

    test('the book changes only the named place', () {
      final book = PlaceBook([
        _place(icon: 'home'),
        NamedPlace(
          id: 'gym',
          name: 'Gym',
          anchors: const [
            PlaceAnchor(latitude: 60.1, longitude: 24.8, radiusM: 200),
          ],
          icon: 'gym',
        ),
      ]);
      final next = book.withIcon('uni', 'school');
      expect(next.byId('uni')!.icon, 'school');
      expect(next.byId('gym')!.icon, 'gym', reason: 'the other place is untouched');
    });

    test('an unknown id changes nothing rather than inventing a place', () {
      final book = PlaceBook([_place(icon: 'home')]);
      final next = book.withIcon('nowhere', 'gym');
      expect(next.length, 1);
      expect(next.byId('uni')!.icon, 'home');
    });
  });
}
