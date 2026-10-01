import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_credits_repository.dart';
import '../../domain/models/credit_models.dart';
import '../../domain/repositories/credits_repository.dart';

final Provider<CreditsRepository> creditsRepositoryProvider =
    Provider<CreditsRepository>(
      (ref) => MockCreditsRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<CreditsOverview> creditsOverviewProvider =
    FutureProvider<CreditsOverview>((ref) {
      return ref.watch(creditsRepositoryProvider).getOverview();
    });
