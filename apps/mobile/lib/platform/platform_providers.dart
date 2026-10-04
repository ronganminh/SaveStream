import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contracts/ads_service.dart';
import 'contracts/connectivity_service.dart';
import 'contracts/device_info_service.dart';
import 'contracts/local_recorder.dart';
import 'contracts/local_recovery_service.dart';
import 'contracts/purchase_service.dart';
import 'contracts/push_service.dart';
import 'fakes/fake_ads_service.dart';
import 'fakes/fake_connectivity_service.dart';
import 'fakes/fake_device_info_service.dart';
import 'fakes/fake_local_recorder.dart';
import 'fakes/fake_local_recovery_service.dart';
import 'fakes/fake_purchase_service.dart';
import 'fakes/fake_push_service.dart';

final Provider<LocalRecorder> localRecorderProvider = Provider<LocalRecorder>(
  (Ref ref) => FakeLocalRecorder(),
);

final Provider<LocalRecorder> secondaryLocalRecorderProvider =
    Provider<LocalRecorder>((Ref ref) => FakeLocalRecorder());

final Provider<LocalRecoveryService> localRecoveryServiceProvider =
    Provider<LocalRecoveryService>((Ref ref) => FakeLocalRecoveryService());

final Provider<PurchaseService> purchaseServiceProvider =
    Provider<PurchaseService>((Ref ref) => FakePurchaseService());

final Provider<AdsService> adsServiceProvider = Provider<AdsService>(
  (Ref ref) => const FakeAdsService(),
);

final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (Ref ref) => FakePushService(),
);

final Provider<ConnectivityService> connectivityServiceProvider =
    Provider<ConnectivityService>((Ref ref) => const FakeConnectivityService());

final Provider<DeviceInfoService> deviceInfoServiceProvider =
    Provider<DeviceInfoService>((Ref ref) => const FakeDeviceInfoService());
