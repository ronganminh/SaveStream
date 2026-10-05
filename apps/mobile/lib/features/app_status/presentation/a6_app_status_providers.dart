import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devices/domain/models/device_registration.dart';
import '../../../../platform/platform_providers.dart';
import '../../../v2_foundation/v2_foundation_providers.dart';
import '../domain/models/app_status.dart';

enum A6GlobalGate { none, updateRequired, maintenance }

final FutureProvider<A6GlobalGate> a6GlobalGateProvider =
    FutureProvider<A6GlobalGate>((Ref ref) async {
  final AppStatus status = await ref.watch(appStatusRepositoryProvider).getStatus();
  if (status.maintenance.active) {
    return A6GlobalGate.maintenance;
  }

  const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '2.0.0',
  );
  final DevicePlatform platform = ref.watch(deviceInfoServiceProvider).platform;
  final String minimumVersion = platform == DevicePlatform.android
      ? status.minSupportedVersion.android
      : status.minSupportedVersion.ios;

  return _isVersionLower(currentVersion, minimumVersion)
      ? A6GlobalGate.updateRequired
      : A6GlobalGate.none;
});

bool _isVersionLower(String current, String minimum) {
  final List<int> currentParts = _versionParts(current);
  final List<int> minimumParts = _versionParts(minimum);
  for (int index = 0; index < 3; index += 1) {
    if (currentParts[index] != minimumParts[index]) {
      return currentParts[index] < minimumParts[index];
    }
  }
  return false;
}

List<int> _versionParts(String value) {
  final List<String> raw = value.split('.').take(3).toList(growable: true);
  while (raw.length < 3) {
    raw.add('0');
  }
  return raw
      .map((String part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9].*'), '')) ?? 0)
      .toList(growable: false);
}
