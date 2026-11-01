library;

import 'package:flutter/widgets.dart';

/// Caps and letter-spacing are Latin-only styling.
///
/// Japanese, Chinese, Korean and Thai have no upper case — `toUpperCase()` is a
/// silent no-op there, so a label that was shouted in English simply sits at
/// normal weight in Tokyo, and wide tracking stretches characters that were
/// designed to sit on a grid. These helpers are the one place the app decides
/// which script it is drawing in.
const Set<String> _caseless = {'ja', 'zh', 'ko', 'th', 'lo', 'my'};

/// True when the language has no upper case and wants no tracking.
bool isCaseless(String languageTag) =>
    _caseless.contains(languageTag.split('-').first.toLowerCase());

/// Upper case where the script has it, untouched where it does not.
String capsFor(BuildContext context, String text) =>
    isCaseless(Localizations.localeOf(context).toLanguageTag())
        ? text
        : text.toUpperCase();

/// The tracking a Latin label would carry, or none for a caseless script.
double trackingFor(BuildContext context, double latinTracking) =>
    isCaseless(Localizations.localeOf(context).toLanguageTag())
        ? 0
        : latinTracking;
