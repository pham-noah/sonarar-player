library;

import 'package:flutter/foundation.dart';

import 'update_service.dart';

/// An update the user asked for, handed to the bar that shows it.
///
/// The switch governs the automatic check only: CHECK NOW is an invitation, so its
/// answer must show even when the switch is off, and the banner lives outside the
/// settings screen. One value, cleared by its consumer, so a stale offer cannot
/// resurface after a relaunch.
final ValueNotifier<AppUpdate?> offeredUpdate = ValueNotifier<AppUpdate?>(null);

/// Offers [update] to the banner. Null withdraws an offer.
void offerUpdate(AppUpdate? update) => offeredUpdate.value = update;
