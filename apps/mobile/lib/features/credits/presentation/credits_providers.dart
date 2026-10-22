import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_providers.dart';
import '../data/mock_credits_repository.dart';
import '../domain/credit_balance.dart';

// Production overrides this with ApiCreditsRepository at bootstrap.
final Provider<CreditsRepository> creditsRepositoryProvider =
    Provider<CreditsRepository>(
      (ref) => MockCreditsRepository(ref.watch(mockBehaviorProvider)),
    );
