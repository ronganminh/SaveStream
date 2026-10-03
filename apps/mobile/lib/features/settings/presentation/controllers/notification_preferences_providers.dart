import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_notifications_repository.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notifications_repository.dart';

final Provider<NotificationPreferencesRepository>
notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
      (ref) => MockNotificationPreferencesRepository(
        ref.watch(mockBehaviorProvider),
      ),
    );

final AsyncNotifierProvider<
  NotificationPreferencesController,
  NotificationPreferences
>
notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() {
    return ref
        .watch(notificationPreferencesRepositoryProvider)
        .getPreferences();
  }

  /// Saves optimistically. Returns false when the backend rejected the change
  /// and the previous preferences were restored.
  Future<bool> save(NotificationPreferences next) async {
    final NotificationPreferences? previous = state.value;
    state = AsyncData<NotificationPreferences>(next);
    try {
      final saved = await ref
          .read(notificationPreferencesRepositoryProvider)
          .updatePreferences(next);
      if (!ref.mounted) return true;
      state = AsyncData<NotificationPreferences>(saved);
      return true;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) return false;
      if (previous != null) {
        state = AsyncData<NotificationPreferences>(previous);
      } else {
        state = AsyncError<NotificationPreferences>(error, stackTrace);
      }
      return false;
    }
  }
}
