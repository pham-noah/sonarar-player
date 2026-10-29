import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/personalization.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  group('the document', () {
    test('round-trips through JSON', () {
      const p = Personalization(
        backdrop: BackdropSpec(
          file: 'sea.jpg',
          focusX: 0.25,
          focusY: 0.75,
          scale: 1.8,
          rotationDeg: -12,
          blur: 6,
          dim: 0.6,
          tint: false,
          coverOnPlayer: true,
        ),
        accent: AccentSpec(source: AccentSource.manual, value: 0xFF00AA88),
        home: HomeLayout(order: [HomeSection.recap, HomeSection.now]),
      );

      final back = Personalization.decode(p.encode());

      expect(back.backdrop.file, 'sea.jpg');
      expect(back.backdrop.focusX, closeTo(0.25, 1e-9));
      expect(back.backdrop.rotationDeg, closeTo(-12, 1e-9));
      expect(back.backdrop.tint, isFalse);
      expect(back.backdrop.coverOnPlayer, isTrue);
      expect(back.accent.source, AccentSource.manual);
      expect(back.accent.value, 0xFF00AA88);
      expect(back.home.order, [HomeSection.recap, HomeSection.now]);
    });

    test('a broken document is yesterday, not an exception', () {
      expect(Personalization.decode('{nope').isDefault, isTrue);
      expect(Personalization.decode('').isDefault, isTrue);
      expect(Personalization.decode(null).isDefault, isTrue);
      expect(Personalization.decode('[]').isDefault, isTrue);
      expect(Personalization.decode(jsonEncode({'v': 1, 'backdrop': 'x'})).isDefault, isTrue);
    });

    test('out-of-range values are clamped, not trusted', () {
      final p = BackdropSpec.fromJson({'file': 'a.jpg', 'scale': 99, 'blur': -4, 'dim': 3, 'rot': 900});
      expect(p.scale, 4.0);
      expect(p.blur, 0.0);
      expect(p.dim, 1.0);
      expect(p.rotationDeg, 180.0);
    });

    test('an empty file name means no backdrop', () {
      expect(const BackdropSpec(file: '').isSet, isFalse);
      expect(BackdropSpec.fromJson({'file': ''}).isSet, isFalse);
      expect(const BackdropSpec(file: 'a.jpg').isSet, isTrue);
    });
  });

  group('Home layout', () {
    test('sections the app adds later are appended, not dropped', () {
      const saved = HomeLayout(order: [HomeSection.recap, HomeSection.now]);
      expect(saved.visible.first, HomeSection.recap);
      expect(saved.visible.length, HomeSection.values.length);
      expect(saved.visible.toSet(), HomeSection.values.toSet());
    });

    test('hidden sections never draw', () {
      final l = HomeLayout.defaults.toggle(HomeSection.rediscover);
      expect(l.visible, isNot(contains(HomeSection.rediscover)));
      expect(l.toggle(HomeSection.rediscover).visible, contains(HomeSection.rediscover));
    });

    test('moving a section lands where it was dropped', () {
      final l = HomeLayout.defaults.move(HomeSection.recap, 0);
      expect(l.visible.first, HomeSection.recap);
      expect(l.visible.length, HomeLayout.defaultOrder.length);
    });

    test('a hidden section is still listed, so it can be turned back on', () {
      final l = HomeLayout.defaults.toggle(HomeSection.recap);
      expect(l.visible, isNot(contains(HomeSection.recap)));
      expect(l.all, contains(HomeSection.recap));
      expect(l.all.length, HomeSection.values.length);
    });

    test('moving a hidden section keeps it hidden and in place', () {
      final l = HomeLayout.defaults
          .toggle(HomeSection.recap)
          .move(HomeSection.recap, 0);
      expect(l.all.first, HomeSection.recap);
      expect(l.visible, isNot(contains(HomeSection.recap)));
    });

    test('unknown names in a saved order are ignored', () {
      final l = HomeLayout.fromJson({
        'order': ['recap', 'was_removed_years_ago', 'now'],
        'hidden': ['nope', 'recap'],
      });
      expect(l.order.first, HomeSection.recap);
      expect(l.visible, isNot(contains(HomeSection.recap)));
    });
  });

  group('accent', () {
    const skinAccent = Color(0xFFE3B84E);

    test('the skin wins unless a source overrides it', () {
      expect(accentFor(skinAccent, const AccentSpec()), skinAccent);
      expect(accentFor(skinAccent, const AccentSpec(source: AccentSource.manual)), skinAccent);
      expect(
        accentFor(skinAccent, const AccentSpec(source: AccentSource.manual, value: 0xFF2255FF)),
        const Color(0xFF2255FF),
      );
    });

    test('text on the accent flips with its luminance', () {
      expect(onAccentFor(const Color(0xFFF2E6C8)), isNot(onAccentFor(const Color(0xFF1A1030))));
      expect(contrastRatio(onAccentFor(const Color(0xFFF2E6C8)), const Color(0xFFF2E6C8)),
          greaterThan(7));
      expect(contrastRatio(onAccentFor(const Color(0xFF1A1030)), const Color(0xFF1A1030)),
          greaterThan(7));
    });

    test('a pale accent gets dark text, a deep one gets light text', () {
      expect(onAccentFor(const Color(0xFFFFE9A8)).computeLuminance(), lessThan(0.2));
      expect(onAccentFor(const Color(0xFF102030)).computeLuminance(), greaterThan(0.5));
    });

    test('the deep shade is darker than the accent it came from', () {
      const accent = Color(0xFF3BA7C8);
      expect(accentDeepFor(accent).computeLuminance(), lessThan(accent.computeLuminance()));
    });
  });

  group('picking an accent out of a photo', () {
    Uint8List pixels(List<Color> colours) {
      final out = Uint8List(colours.length * 4);
      for (var i = 0; i < colours.length; i++) {
        out[i * 4] = (colours[i].r * 255).round();
        out[i * 4 + 1] = (colours[i].g * 255).round();
        out[i * 4 + 2] = (colours[i].b * 255).round();
        out[i * 4 + 3] = 255;
      }
      return out;
    }

    test('a grey photo suggests nothing rather than inventing a colour', () {
      final grey = List<Color>.generate(64, (i) => Color.from(alpha: 1, red: 0.5, green: 0.5, blue: 0.5));
      expect(pickAccentFromPixels(pixels(grey)), isNull);
    });

    test('a black photo suggests nothing', () {
      final dark = List<Color>.filled(64, const Color(0xFF000000));
      expect(pickAccentFromPixels(pixels(dark)), isNull);
    });

    test('the saturated colour wins over the neutral one', () {
      final shot = <Color>[
        ...List<Color>.filled(40, Color.from(alpha: 1, red: 0.82, green: 0.80, blue: 0.78)),
        ...List<Color>.filled(12, Color.from(alpha: 1, red: 0.85, green: 0.20, blue: 0.18)),
      ];
      final picked = pickAccentFromPixels(pixels(shot));
      expect(picked, isNotNull);
      expect(picked!.r, greaterThan(picked.b));
      expect(picked.r, greaterThan(0.5));
    });

    test('a dark pick is lifted enough to act as an accent', () {
      final shot = List<Color>.filled(32, Color.from(alpha: 1, red: 0.18, green: 0.10, blue: 0.42));
      final picked = pickAccentFromPixels(pixels(shot));
      expect(picked, isNotNull);
      expect(picked!.computeLuminance(), greaterThan(0.05));
    });
  });

  group('skin', () {
    test('a new accent carries a matching deep shade and text colour', () {
      const accent = Color(0xFFFF3355);
      final skinned = kSkinCrimson.withAccent(accent);

      expect(skinned.accent, accent);
      expect(skinned.accentDeep, accentDeepFor(accent));
      expect(skinned.onAccent, onAccentFor(accent));
      expect(skinned.background, kSkinCrimson.background);
      expect(skinned.panel, kSkinCrimson.panel);
      expect(skinned.skewDegrees, kSkinCrimson.skewDegrees);
      expect(skinned.word('nowPlaying', 'x'), kSkinCrimson.word('nowPlaying', 'x'));
    });
  });
}
