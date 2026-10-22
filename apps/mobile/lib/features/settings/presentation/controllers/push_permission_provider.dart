import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../platform/contracts/push_service.dart';
import '../../../../platform/platform_providers.dart';

final AsyncNotifierProvider<PushPermissionController, PushPermissionStatus>
pushPermissionProvider =
    AsyncNotifierProvider<PushPermissionController, PushPermissionStatus>(
      PushPermissionController.new,
    );

class PushPermissionController extends AsyncNotifier<PushPermissionStatus> {
  @override
  Future<PushPermissionStatus> build() {
    return ref.watch(pushServiceProvider).permissionStatus;
  }

  Future<void> request() async {
    state = const AsyncLoading<PushPermissionStatus>();
    state = await AsyncValue.guard<PushPermissionStatus>(
      () => ref.read(pushServiceProvider).requestPermission(),
    );
  }

  /// Opens the system notification settings; [refresh] runs again when the
  /// app comes back to the foreground.
  Future<bool> openSystemSettings() {
    return ref.read(pushServiceProvider).openSystemSettings();
  }

  /// Re-reads the OS permission (e.g. back from the system settings) without
  /// showing a loading state.
  Future<void> refresh() async {
    final AsyncValue<PushPermissionStatus> next =
        await AsyncValue.guard<PushPermissionStatus>(
          () => ref.read(pushServiceProvider).permissionStatus,
        );
    if (!ref.mounted) return;
    state = next;
  }
}
