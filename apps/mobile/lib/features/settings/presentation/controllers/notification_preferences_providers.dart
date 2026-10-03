import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_providers.dart';
import '../../data/repositories/api_notification_preferences_repository.dart';
import '../../domain/models/notification_preferences.dart';

final Provider<ApiNotificationPreferencesRepository>
notificationPreferencesRepositoryProvider =
    Provider<ApiNotificationPreferencesRepository>((ref) {
      return ApiNotificationPreferencesRepository(
        apiClient: ref.watch(apiClientProvider),
      );
    });

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
    return ref.watch(notificationPreferencesRepositoryProvider).getPreferences();
  }

  Future<void> update(NotificationPreferences next) async {
    final NotificationPreferences? previous = state.value;
    state = AsyncData<NotificationPreferences>(next);
    try {
      final saved = await ref
          .read(notificationPreferencesRepositoryProvider)
          .updatePreferences(next);
      state = AsyncData<NotificationPreferences>(saved);
    } on Object catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData<NotificationPreferences>(previous);
      } else {
        state = AsyncError<NotificationPreferences>(error, stackTrace);
      }
    }
  }
}
