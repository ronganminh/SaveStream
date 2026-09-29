enum MockScenario { success, loading, empty, error, offlineLike }

class MockBehavior {
  const MockBehavior({
    this.scenario = MockScenario.success,
    this.latency = const Duration(milliseconds: 160),
  });

  final MockScenario scenario;
  final Duration latency;
}
