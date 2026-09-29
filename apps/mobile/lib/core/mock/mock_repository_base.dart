import 'dart:async';

import 'mock_scenario.dart';

enum MockFailureKind { server, offlineLike }

class MockRepositoryException implements Exception {
  const MockRepositoryException(this.kind);

  final MockFailureKind kind;
}

abstract base class MockRepositoryBase {
  const MockRepositoryBase(this.behavior);

  final MockBehavior behavior;

  Future<T> respond<T>({
    required T Function() success,
    required T Function() empty,
  }) async {
    if (behavior.scenario == MockScenario.loading) {
      return Completer<T>().future;
    }

    await Future<void>.delayed(behavior.latency);

    return switch (behavior.scenario) {
      MockScenario.success => success(),
      MockScenario.empty => empty(),
      MockScenario.error => throw const MockRepositoryException(
        MockFailureKind.server,
      ),
      MockScenario.offlineLike => throw const MockRepositoryException(
        MockFailureKind.offlineLike,
      ),
      MockScenario.loading => throw StateError('Unreachable mock scenario.'),
    };
  }
}
