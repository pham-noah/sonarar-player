library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Localizations for a context, with English as the floor.
///
/// One helper instead of an accessor on every State: screens, dialogs and
/// small widgets all have a context, and a widget rendered on its own (a test,
/// an embed) must not crash because nobody installed the delegate above it.
AppLocalizations l10nOf(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    lookupAppLocalizations(const Locale('en'));
