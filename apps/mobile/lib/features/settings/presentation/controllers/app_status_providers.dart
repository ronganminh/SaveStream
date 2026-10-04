import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_app_status_repository.dart';
import '../../domain/models/app_status.dart';
import '../../domain/repositories/app_status_repository.dart';

final Provider<AppStatusRepository> appStatusRepositoryProvider =
    Provider<AppStatusRepository>(
      (Ref ref) => MockAppStatusRepository(ref.watch(mockBehaviorProvider)),
    );

final FutureProvider<AppStatus> appStatusProvider =
    FutureProvider<AppStatus>(
      (Ref ref) => ref.watch(appStatusRepositoryProvider).getStatus(),
    );
