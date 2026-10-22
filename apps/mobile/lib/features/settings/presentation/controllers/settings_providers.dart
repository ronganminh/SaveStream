import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/app_session_controller.dart';
import '../../../../core/mock/mock_providers.dart';
import '../../../../platform/contracts/device_info_service.dart';
import '../../../../platform/platform_providers.dart';
import '../../../auth/data/auth_providers.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../devices/domain/repositories/device_repository.dart';
import '../../../v2_foundation/v2_foundation_providers.dart';
import '../../data/repositories/mock_profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
      (ref) => MockProfileRepository(ref.watch(mockBehaviorProvider)),
    );

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final settingsAccountControllerProvider =
    Provider.family<SettingsAccountController, AppSessionController>(
      (ref, session) => SettingsAccountController(
        repository: ref.watch(authRepositoryProvider),
        session: session,
        devices: ref.watch(deviceRepositoryProvider),
        deviceInfo: ref.watch(deviceInfoServiceProvider),
      ),
    );

class SettingsAccountController {
  const SettingsAccountController({
    required AuthRepository repository,
    required AppSessionController session,
    required DeviceRepository devices,
    required DeviceInfoService deviceInfo,
  }) : _repository = repository,
       _session = session,
       _devices = devices,
       _deviceInfo = deviceInfo;

  final AuthRepository _repository;
  final AppSessionController _session;
  final DeviceRepository _devices;
  final DeviceInfoService _deviceInfo;

  /// Sign out: this device stops getting pushes for the account
  /// (DELETE /v1/me/devices/{id}, best effort), then the session is
  /// revoked and cleared.
  Future<void> logout() async {
    try {
      await _devices.unregister(await _deviceInfo.deviceId);
    } on Object {
      // Offline or already gone; signing out still goes ahead.
    }
    await _repository.logout();
    _session.markUnauthenticated();
  }

  /// DELETE /v1/me, as before. The repository clears the local session;
  /// the app is signed out with [finishDeletion] once the confirmation
  /// screen is up.
  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
  }

  void finishDeletion() => _session.markUnauthenticated();
}
