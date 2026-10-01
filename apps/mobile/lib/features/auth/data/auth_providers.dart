import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_providers.dart';
import '../domain/repositories/auth_repository.dart';
import 'repositories/mock_auth_repository.dart';

final Provider<AuthMockScenario> authMockScenarioProvider =
    Provider<AuthMockScenario>((ref) => AuthMockScenario.success);

// Production overrides this provider with ApiAuthRepository at bootstrap.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
      final behavior = ref.watch(mockBehaviorProvider);
      return MockAuthRepository(
        scenario: ref.watch(authMockScenarioProvider),
        latency: behavior.latency,
      );
    });
