library;

import 'package:flutter/material.dart';

import 'layout.dart';

double relativeLuminance(Color c) => c.computeLuminance();

double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

const double kMinTextContrast = 4.5;

enum ThemeIssueSeverity {
  error,

  warning,
}

class ThemeIssue {
  const ThemeIssue(this.field, this.message, {this.severity = ThemeIssueSeverity.error});

  final String field;

  final String message;

  final ThemeIssueSeverity severity;

  bool get isError => severity == ThemeIssueSeverity.error;

  @override
  String toString() => '${severity.name}: $field: $message';
}

List<ThemeIssue> checkPalette(LayoutPalette palette) {
  final issues = <ThemeIssue>[];

  void needsContrast(
    String field,
    Color fg,
    Color bg,
    double floor, {
    ThemeIssueSeverity severity = ThemeIssueSeverity.error,
  }) {
    final ratio = contrastRatio(fg, bg);
    if (ratio < floor) {
      issues.add(ThemeIssue(
        field,
        'contrast ${ratio.toStringAsFixed(2)}:1 against the page, '
        'below the ${floor.toStringAsFixed(1)}:1 floor',
        severity: severity,
      ));
    }
  }

  final page = palette.pageFill ?? palette.background;

  needsContrast('textPrimary', palette.textPrimary, page, kMinTextContrast);
  needsContrast('textSecondary', palette.textSecondary, page, kMinTextContrast);
  needsContrast('onAccent', palette.onAccent, palette.accent, kMinTextContrast);
  needsContrast('accent', palette.accent, page, 3.0,
      severity: ThemeIssueSeverity.warning);

  return issues;
}

bool isDarkBackground(Color background) =>
    relativeLuminance(background) < 0.5;
