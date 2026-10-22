import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'contracts/connectivity_service.dart';
import 'contracts/device_info_service.dart';
import 'contracts/purchase_service.dart';
import 'contracts/push_service.dart';
import 'contracts/share_service.dart';
import 'fakes/fake_connectivity_service.dart';
import 'fakes/fake_device_info_service.dart';
import 'fakes/fake_purchase_service.dart';
import 'fakes/fake_push_service.dart';

final Provider<PurchaseService> purchaseServiceProvider =
    Provider<PurchaseService>((Ref ref) => FakePurchaseService());

final Provider<PushService> pushServiceProvider = Provider<PushService>(
  (Ref ref) => FakePushService(),
);

final Provider<ConnectivityService> connectivityServiceProvider =
    Provider<ConnectivityService>((Ref ref) => const FakeConnectivityService());

final Provider<DeviceInfoService> deviceInfoServiceProvider =
    Provider<DeviceInfoService>((Ref ref) => const FakeDeviceInfoService());

final Provider<ShareService> shareServiceProvider = Provider<ShareService>(
  (Ref ref) => FakeShareService(),
);
