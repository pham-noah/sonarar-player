library;

import 'package:flutter/foundation.dart';

import 'update_service.dart';

/// An update the user asked for, handed to the bar that shows it.
///
/// The update switch governs the *automatic* check: off means the app does not
/// phone home on its own. Pressing CHECK NOW is an invitation, so its answer has
/// to be visible even when the switch is off — and the answer lives in a banner
/// the settings screen does not own. This is the wire between them.
///
/// One value, cleared by whoever consumed it, so a stale offer cannot resurface
/// after the app has been updated and relaunched.
final ValueNotifier<AppUpdate?> offeredUpdate = ValueNotifier<AppUpdate?>(null);

/// Offers [update] to the banner. Null withdraws an offer.
void offerUpdate(AppUpdate? update) => offeredUpdate.value = update;
