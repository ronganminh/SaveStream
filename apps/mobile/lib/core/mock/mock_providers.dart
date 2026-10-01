import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_scenario.dart';

final Provider<MockScenario> mockScenarioProvider = Provider<MockScenario>(
  (ref) => MockScenario.success,
);

final Provider<MockBehavior> mockBehaviorProvider = Provider<MockBehavior>(
  (ref) => MockBehavior(scenario: ref.watch(mockScenarioProvider)),
);
