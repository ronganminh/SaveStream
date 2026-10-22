// Renders the System v2 screens (No connection, Server error, Maintenance,
// Update required) on the Android emulator with the real engine and
// bundled fonts, for comparison with the artboards. CI runs it with
// --dart-define=SAVESTREAM_SCREENSHOT_DIR=device and pulls the PNGs.
import 'package:integration_test/integration_test.dart';

import '../test/screenshots/system_screens_test.dart' as screens;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  screens.main();
}
