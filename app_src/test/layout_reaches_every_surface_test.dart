library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/theme/layout.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  group('the layout reaches every surface', () {
    test('no screen or widget draws from the RAW palette skin', () {
      final offenders = <String>[];
      for (final dir in ['lib/screens', 'lib/widgets']) {
        for (final f in Directory(dir).listSync(recursive: true)) {
          if (f is! File || !f.path.endsWith('.dart')) continue;
          final text = f.readAsStringSync();
          final rawLocal = RegExp(r'final skin = (widget\.)?state\.skin;');
          final rawArgument = RegExp(r'skin: (widget\.)?state\.skin[,)]');
          if (rawLocal.hasMatch(text) || rawArgument.hasMatch(text)) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'these resolve the raw palette instead of the layout:\n'
              '${offenders.join('\n')}\n'
              'Use `PresentationScope.uiSkin(context, skin)` — it returns the palette itself for Persona, '
              'so Persona cannot move, and the layout for everything else.');
    });

    test('uiSkin is the palette ITSELF for Persona, so nothing Persona draws can move', () {
      final chosen = skinFor(SkinId.crimson);
      final persona = presentationFor(LayoutKind.persona, chosen);
      expect(identical(persona.asSkin(chosen), chosen), isTrue,
          reason: 'Persona must hand back the identical skin object');
    });

    test('and it is a DIFFERENT skin for the plain layouts — otherwise the accessor is a no-op', () {
      final chosen = skinFor(SkinId.crimson);
      for (final layout in [LayoutKind.solid, LayoutKind.glass]) {
        final p = presentationFor(layout, chosen);
        expect(identical(p.asSkin(chosen), chosen), isFalse,
            reason: '${layout.name} must wear its own colours, not Persona\'s');
      }
    });

    test('every layout resolves through the SAME entry point', () {
      for (final layout in LayoutKind.values) {
        final p = presentationFor(layout, skinFor(SkinId.abyss));
        final viaPresentation = p.asSkin(skinFor(SkinId.abyss));
        expect(viaPresentation.id, isNotNull);
      }
    });
  });
}
