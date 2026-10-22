import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the SIL Open Font License texts of the bundled fonts to the app's
/// license page (the OFL requires the license to ship with the fonts).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/fonts/PlusJakartaSans-OFL.txt'));
    yield LicenseEntryWithLineBreaks(const <String>[
      'Geist Mono',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
}
