import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_settings_store.dart';
import '../../../../core/storage/shared_preferences_app_settings_store.dart';

const String _localRecordingConfirmedKey =
    'local_recording_start_confirmed_v1';

final Provider<AppSettingsStore> localRecordingSettingsStoreProvider =
    Provider<AppSettingsStore>((Ref ref) => SharedPreferencesAppSettingsStore());

final Provider<LocalRecordingConfirmationController>
localRecordingConfirmationControllerProvider =
    Provider<LocalRecordingConfirmationController>((Ref ref) {
      return LocalRecordingConfirmationController(
        store: ref.watch(localRecordingSettingsStoreProvider),
      );
    });

class LocalRecordingConfirmationController {
  const LocalRecordingConfirmationController({
    required AppSettingsStore store,
  }) : _store = store;

  final AppSettingsStore _store;

  Future<bool> shouldConfirm({bool force = false}) async {
    if (force) return true;
    final String? value = await _store.readString(
      _localRecordingConfirmedKey,
    );
    return value != 'true';
  }

  Future<void> markConfirmed() {
    return _store.writeString(_localRecordingConfirmedKey, 'true');
  }
}
