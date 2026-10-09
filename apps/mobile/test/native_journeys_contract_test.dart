// Reuse every real-device UI journey in the fast Flutter widget-test runner.
// Android/iOS CI separately executes the same journeys inside OS simulators.
import '../test_support/native_journeys.dart';

void main() => registerDeviceJourneys();
