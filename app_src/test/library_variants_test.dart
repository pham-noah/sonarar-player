@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/library/variants.dart';

void main() {
  late List<Track> library;

  setUpAll(() {
    final file = File('test/fixtures/library_manifest.json');
    expect(file.existsSync(), isTrue,
        reason: 'the manifest the app ships must exist');
    final doc = jsonDecode(file.readAsStringSync());
    final raw = (doc as Map<String, dynamic>)['tracks'] as List<dynamic>;
    library = [
      for (final t in raw) Track.fromJson(t as Map<String, dynamic>),
    ];
  });

  test('the manifest parses, and the variant fields survive parsing', () {
    expect(library, isNotEmpty);
    expect(library.length, greaterThan(200));
  });

  test('variants exist, so the feature is not inert', () {
    final withLinks = library.where((t) => t.variantOf != null).toList();
    expect(withLinks, isNotEmpty,
        reason: 'no track declares variant_of, so nothing can ever be swapped');
    for (final t in withLinks) {
      expect(isKnownVariantTag(t.variantTag), isTrue,
          reason: '${t.title} links to a parent but its tag is not one this app knows');
    }
  });

  test('every variant_of names a track that is actually in the library', () {
    final ids = {for (final t in library) t.id};
    for (final t in library.where((t) => t.variantOf != null)) {
      expect(ids.contains(t.variantOf), isTrue,
          reason: '${t.title} points at ${t.variantOf}, which is not in the library');
    }
  });

  test('Beneath the Mask: the instrumental is the base and both rain cuts hang off it',
      () {
    Track? byTitle(String s) {
      for (final t in library) {
        if (t.title == s) return t;
      }
      return null;
    }

    final inst = byTitle('Beneath the Mask -instrumental version');
    final rain = byTitle('Beneath the Mask -rain');
    final rainInst = byTitle('Beneath the Mask -rain, instrumental version');
    expect(inst, isNotNull);
    expect(rain, isNotNull);
    expect(rainInst, isNotNull);

    expect(inst!.variantOf, isNull, reason: 'it is the base of its family');
    expect(rain!.variantOf, inst.id);
    expect(rainInst!.variantOf, inst.id);
    expect(rain.variantTag, 'rain');
    expect(rainInst.variantTag, 'rain');
  });

  test('a real swap can be offered: the album cut leads the rain version', () {
    Track? rain;
    for (final t in library) {
      if (t.title == 'Beneath the Mask -rain') rain = t;
    }
    final options = variantsOf(rain!, library);
    expect(options, isNotEmpty, reason: 'there is somewhere to go from the rain cut');

    expect(options.first.title, 'Beneath the Mask -instrumental version');
  });

  test('a family of one offers nothing, which is the common case', () {
    final lonely = library.firstWhere(
      (t) => t.variantOf == null && !library.any((o) => o.variantOf == t.id),
    );
    expect(variantsOf(lonely, library), isEmpty);
  });
}
