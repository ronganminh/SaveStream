import 'package:integration_test/integration_test.dart';

import '../test_support/native_journeys.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerDeviceJourneys();
}
