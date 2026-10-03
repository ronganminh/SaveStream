import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mock/mock_providers.dart';
import '../app_status/data/repositories/mock_app_status_repository.dart';
import '../app_status/domain/repositories/app_status_repository.dart';
import '../devices/data/repositories/mock_device_repository.dart';
import '../devices/domain/repositories/device_repository.dart';
import '../entitlement/data/repositories/mock_entitlement_repository.dart';
import '../entitlement/domain/repositories/entitlement_repository.dart';
import '../local_recordings/data/repositories/mock_local_recording_repository.dart';
import '../local_recordings/domain/repositories/local_recording_repository.dart';
import '../rewards/data/repositories/mock_reward_repository.dart';
import '../rewards/domain/repositories/reward_repository.dart';
import '../store/data/repositories/mock_store_repository.dart';
import '../store/domain/repositories/store_repository.dart';

final Provider<EntitlementRepository> entitlementRepositoryProvider =
    Provider<EntitlementRepository>(
  (Ref ref) => MockEntitlementRepository(ref.watch(mockBehaviorProvider)),
);

final Provider<LocalRecordingRepository> localRecordingRepositoryProvider =
    Provider<LocalRecordingRepository>(
  (Ref ref) => MockLocalRecordingRepository(ref.watch(mockBehaviorProvider)),
);

final Provider<RewardRepository> rewardRepositoryProvider =
    Provider<RewardRepository>(
  (Ref ref) => MockRewardRepository(ref.watch(mockBehaviorProvider)),
);

final Provider<StoreRepository> storeRepositoryProvider =
    Provider<StoreRepository>(
  (Ref ref) => MockStoreRepository(ref.watch(mockBehaviorProvider)),
);

final Provider<AppStatusRepository> appStatusRepositoryProvider =
    Provider<AppStatusRepository>(
  (Ref ref) => MockAppStatusRepository(ref.watch(mockBehaviorProvider)),
);

final Provider<DeviceRepository> deviceRepositoryProvider =
    Provider<DeviceRepository>(
  (Ref ref) => MockDeviceRepository(ref.watch(mockBehaviorProvider)),
);
