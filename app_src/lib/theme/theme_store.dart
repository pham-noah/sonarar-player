library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'theme_definition.dart';
import 'theme_validation.dart' show ThemeIssue;

const String kUserThemesDirName = 'themes';

class ThemeRegistry {
  const ThemeRegistry(this.themes, this.rejected);

  final Map<String, ThemeDefinition> themes;

  final Map<String, List<ThemeIssue>> rejected;

  Iterable<ThemeDefinition> get builtIns =>
      themes.values.where((t) => t.builtIn);

  Iterable<ThemeDefinition> get userThemes =>
      themes.values.where((t) => !t.builtIn);
}

class ThemeStore {
  const ThemeStore();

  Future<Map<String, ThemeDefinition>> loadBundled(
      Future<String?> Function(String path) readAsset) async {
    final out = <String, ThemeDefinition>{};
    for (final name in kBuiltInThemeFiles) {
      final raw = await readAsset('assets/themes/$name');
      if (raw == null) {
        debugPrint('[THEME] $name is listed but not in the bundle');
        continue;
      }
      _absorb(out, raw, name);
    }
    return out;
  }

  Future<Map<String, ThemeDefinition>> loadUser(String? stateDir) async {
    final out = <String, ThemeDefinition>{};
    if (stateDir == null || stateDir.isEmpty) return out;
    final dir = Directory('$stateDir/$kUserThemesDirName');
    if (!dir.existsSync()) return out;

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      _absorb(out, file.readAsStringSync(), _basename(file.path));
    }
    return out;
  }

  void _absorb(Map<String, ThemeDefinition> into, String source, String name) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      debugPrint('[THEME] $name is not valid JSON: $e');
      into.remove(name);
      return;
    }
    ThemeDefinition.decode(json, sourceName: name).when(
      valid: (theme) {
        if (into.containsKey(theme.id)) {
          debugPrint('[THEME] $name declares id "${theme.id}", which is already '
              'taken — the first file wins and this one is skipped');
          return;
        }
        into[theme.id] = theme;
      },
      invalid: (issues) {
        debugPrint('[THEME] $name was skipped:');
        for (final i in issues) {
          debugPrint('[THEME]   $i');
        }
      },
    );
  }
}

const List<String> kBuiltInThemeFiles = [
  'persona_abyss.json',
  'persona_amber.json',
  'persona_crimson.json',
  'persona_minimal.json',
  'persona_mono.json',
  'persona_bloom.json',
  'solid_forest.json',
  'solid_midnight.json',
  'solid_ember.json',
  'glass_aurora.json',
  'glass_jade.json',
  'glass_sunset.json',
];

String _basename(String path) =>
    path.split(RegExp(r'[\\/]')).last;
