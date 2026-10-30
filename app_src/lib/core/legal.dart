library;

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

/// Flutter lists the licences of the packages it knows about. The licence this
/// build is under, and the notice that explains why, are ours — so they are
/// registered by hand. Without this the one licence the app cannot omit is the
/// one missing from the list.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final gpl = await rootBundle.loadString('assets/legal/LICENSE');
    yield LicenseEntryWithLineBreaks(const ['Sonarar'], gpl);
  });
  LicenseRegistry.addLicense(() async* {
    final notice = await rootBundle.loadString('assets/legal/NOTICE.md');
    yield LicenseEntryWithLineBreaks(const ['Third-party notices'], notice);
  });
}
