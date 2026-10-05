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
}
