// Renders the Channels v2 screens on the Android emulator with the real
// engine and bundled fonts, for comparison with the artboards. CI runs it
// with --dart-define=SAVESTREAM_SCREENSHOT_DIR=device and pulls the PNGs.
import 'package:integration_test/integration_test.dart';

import '../test/screenshots/channels_screens_test.dart' as screens;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  screens.main();
}
