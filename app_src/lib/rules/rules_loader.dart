library;

import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'context_rules.dart';

const String kBundledRules = 'assets/config/rules.json';

class ContextRulesLoader {
  ContextRulesLoader({required this.file, AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final File file;
  final AssetBundle _bundle;

  Future<ContextRules> load() async {
    if (file.existsSync()) {
      try {
        final rules = ContextRules.decode(await file.readAsString());
        return rules;
      } on FileSystemException {
        // ignore: empty_catches
      }
    }

    final seeded = await _fromBundle();
    if (seeded.isEmpty) return ContextRules.empty;
    try {
      await save(seeded);
    } on FileSystemException {
      // ignore: empty_catches
    }
    return seeded;
  }

  Future<ContextRules> _fromBundle() async {
    try {
      return ContextRules.decode(await _bundle.loadString(kBundledRules));
    } catch (_) {
      return ContextRules.empty;
    }
  }

  Future<void> save(ContextRules rules) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(rules.encode());
  }
}
