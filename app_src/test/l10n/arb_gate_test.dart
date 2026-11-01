import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The gate for every language the app ships.
///
/// A missing key falls back to English silently, so a half-translated build
/// looks finished and a golden test cannot tell. These checks run as ordinary
/// tests, which means CI fails on them the day a locale drifts — not the day
/// someone remembers to look.
void main() {
  final dir = Directory('lib/l10n');
  final templateFile = File('${dir.path}/app_en.arb');

  Map<String, dynamic> read(File f) =>
      json.decode(f.readAsStringSync()) as Map<String, dynamic>;

  /// Keys that carry meaning; the `@key` metadata entries are not text.
  Set<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  /// `{name}` and `{count, plural, ...}` both declare placeholders.
  ///
  /// Depth matters: the `once` in `=1{once}` is a branch of the plural, not a
  /// placeholder, and a flat regex cannot tell the difference.
  Set<String> placeholdersOf(String message) {
    final found = <String>{};
    var depth = 0;
    for (var i = 0; i < message.length; i++) {
      final c = message[i];
      if (c == '{') {
        if (depth == 0) {
          final name = RegExp(r'^\{([A-Za-z_][\w]*)').firstMatch(message.substring(i));
          if (name != null) found.add(name.group(1)!);
        }
        depth++;
      } else if (c == '}') {
        depth--;
      }
    }
    return found;
  }

  bool isPlural(String message) =>
      RegExp(r'\{\w+,\s*plural,').hasMatch(message);

  final template = read(templateFile);
  final templateKeys = keysOf(template);

  final locales = dir
      .listSync()
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.arb') &&
          !f.path.endsWith('app_en.arb') &&
          !f.path.endsWith('.README.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the template is the source of truth and is not empty', () {
    expect(templateKeys.length, greaterThan(300));
  });

  for (final file in locales) {
    final name = file.uri.pathSegments.last;
    final arb = read(file);
    final keys = keysOf(arb);

    test('$name has every key the template has', () {
      final missing = templateKeys.difference(keys).toList()..sort();
      expect(missing, isEmpty,
          reason: '$name is missing ${missing.length} keys: '
              '${missing.take(12).join(', ')}');
    });

    test('$name has no key the template does not have', () {
      final extra = keys.difference(templateKeys).toList()..sort();
      expect(extra, isEmpty,
          reason: '$name invents ${extra.length} keys: '
              '${extra.take(12).join(', ')}');
    });

    test('$name keeps every placeholder, in every message', () {
      final problems = <String>[];
      for (final key in templateKeys.intersection(keys)) {
        final want = placeholdersOf(template[key] as String);
        final got = placeholdersOf(arb[key] as String);
        if (!want.containsAll(got) || !got.containsAll(want)) {
          problems.add('$key wants {$want} but has {$got}');
        }
      }
      expect(problems, isEmpty, reason: problems.take(10).join('\n'));
    });

    test('$name keeps "other" on every plural', () {
      final problems = <String>[];
      for (final key in templateKeys.intersection(keys)) {
        final source = template[key] as String;
        final translated = arb[key] as String;
        if (!isPlural(source)) continue;
        if (!RegExp(r'\{\s*\w+\s*,\s*plural,').hasMatch(translated) ||
            !RegExp(r'\bother\s*\{').hasMatch(translated)) {
          problems.add('$key lost its plural or its "other" branch');
        }
      }
      expect(problems, isEmpty, reason: problems.take(10).join('\n'));
    });
  }

  test('no ARB key is left unreferenced in lib', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final orphans = templateKeys
        .where((k) => !RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(sources))
        .toList()
      ..sort();

    expect(orphans, isEmpty,
        reason: 'An orphaned key is a translation someone pays for: '
            '${orphans.join(', ')}');
  });

  test('every {placeholder} in the template is declared', () {
    final problems = <String>[];
    for (final key in templateKeys) {
      final declared =
          ((template['@$key'] as Map<String, dynamic>?)?['placeholders']
                  as Map<String, dynamic>?)
              ?.keys
              .toSet() ??
          <String>{};
      final used = placeholdersOf(template[key] as String);
      final undeclared = used.difference(declared);
      if (undeclared.isNotEmpty) {
        problems.add('$key uses {$undeclared} without declaring it');
      }
    }
    expect(problems, isEmpty, reason: problems.take(10).join('\n'));
  });
}
