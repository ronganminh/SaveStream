import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/storage/app_settings_store.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/controllers/local_recording_confirmation_controller.dart';

void main() {
  test('R01 confirms once, then allows one-tap recording', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        localRecordingSettingsStoreProvider.overrideWithValue(
          MemoryAppSettingsStore(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final LocalRecordingConfirmationController controller = container.read(
      localRecordingConfirmationControllerProvider,
    );

    expect(await controller.shouldConfirm(), isTrue);

    await controller.markConfirmed();

    expect(await controller.shouldConfirm(), isFalse);
    expect(await controller.shouldConfirm(force: true), isTrue);
  });
}
