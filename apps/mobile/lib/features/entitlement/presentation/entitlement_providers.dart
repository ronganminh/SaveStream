import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_providers.dart';
import '../../../platform/platform_providers.dart';
import '../data/repositories/mock_entitlement_repository.dart';
import '../domain/models/entitlement.dart';
import '../domain/repositories/entitlement_repository.dart';

final Provider<EntitlementRepository> entitlementRepositoryProvider =
    Provider<EntitlementRepository>(
      (ref) => MockEntitlementRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<Entitlement> entitlementProvider =
    FutureProvider<Entitlement>(
      (ref) => ref.watch(entitlementRepositoryProvider).getEntitlement(),
    );

final StreamProvider<bool> appOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).online,
);
