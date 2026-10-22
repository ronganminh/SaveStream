import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/api/api_exception.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../v2_foundation/v2_foundation_providers.dart';
import '../domain/models/app_status.dart';

/// The installed app version ("2.0.1") from the package info; the
/// APP_VERSION define when the platform can't say (tests).
final FutureProvider<String> appVersionProvider = FutureProvider<String>((
  Ref ref,
) async {
  try {
    final String version = (await PackageInfo.fromPlatform()).version;
    if (version.isNotEmpty) return version;
  } on Object {
    // Falls back below.
  }
  return const String.fromEnvironment('APP_VERSION', defaultValue: '2.0.0');
});

/// What blocks the signed-in app (full-screen system states).
enum SystemGate { none, updateRequired, maintenance, serverError }

class SystemStatus {
  const SystemStatus(
    this.gate, {
    this.maintenanceEta,
    this.installedVersion = '',
    this.requiredVersion = '',
    this.requestId,
  });

  static const SystemStatus open = SystemStatus(SystemGate.none);

  final SystemGate gate;

  /// Maintenance: when the server expects to be back (UTC), if it says.
  final DateTime? maintenanceEta;

  /// Update required: the installed and the minimum supported version.
  final String installedVersion;
  final String requiredVersion;

  /// Server error: the failed request's id, for support.
  final String? requestId;
}

/// GET /v1/app/status: maintenance, the minimum supported version for this
/// platform, or a server error. Network failures leave the app open (the
/// connectivity state shows "No connection").
final FutureProvider<SystemStatus>
systemStatusProvider = FutureProvider<SystemStatus>((Ref ref) async {
  final AppStatus status;
  try {
    status = await ref.watch(appStatusRepositoryProvider).getStatus();
  } on ApiException catch (error) {
    if (error.kind == ApiExceptionKind.server) {
      return SystemStatus(SystemGate.serverError, requestId: error.requestId);
    }
    return SystemStatus.open;
  }
  if (status.maintenance.active) {
    return SystemStatus(
      SystemGate.maintenance,
      maintenanceEta: status.maintenance.eta,
    );
  }
  final String installed = await ref.watch(appVersionProvider.future);
  final DevicePlatform platform = ref.watch(deviceInfoServiceProvider).platform;
  final String minimum = platform == DevicePlatform.android
      ? status.minSupportedVersion.android
      : status.minSupportedVersion.ios;
  return isVersionLower(installed, minimum)
      ? SystemStatus(
          SystemGate.updateRequired,
          installedVersion: installed,
          requiredVersion: minimum,
        )
      : SystemStatus.open;
});

bool isVersionLower(String current, String minimum) {
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
      .map(
        (String part) =>
            int.tryParse(part.replaceAll(RegExp(r'[^0-9].*'), '')) ?? 0,
      )
      .toList(growable: false);
}
