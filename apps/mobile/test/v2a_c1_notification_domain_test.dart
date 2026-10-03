import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/features/settings/data/repositories/mock_notifications_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/models/notification_preferences.dart';

void main() {
  const MockBehavior behavior = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );

  test('V2 notification domain exposes C1 notification types', () {
    expect(
      AppNotificationType.values,
      containsAll(<AppNotificationType>[
        AppNotificationType.creatorLive,
        AppNotificationType.recordingExpiring,
        AppNotificationType.freeMinutesLow,
      ]),
    );
  });

  test('V2 notification preferences default new switches to on', () {
    const NotificationPreferences preferences = NotificationPreferences(
      recordingStarted: true,
      recordingReady: true,
      recordingFailed: true,
    );

    expect(preferences.creatorLive, isTrue);
    expect(preferences.recordingExpiring, isTrue);
    expect(preferences.freeMinutesLow, isTrue);

    final NotificationPreferences updated = preferences.copyWith(
      creatorLive: false,
      recordingExpiring: false,
      freeMinutesLow: false,
    );
    expect(updated.creatorLive, isFalse);
    expect(updated.recordingExpiring, isFalse);
    expect(updated.freeMinutesLow, isFalse);
  });

  test('notification mocks seed all C1 V2 notification kinds', () async {
    final MockNotificationsRepository repository = MockNotificationsRepository(
      behavior,
    );

    final NotificationPage page = await repository.listNotifications();

    expect(
      page.items.map((AppNotification item) => item.type),
      containsAll(<AppNotificationType>[
        AppNotificationType.creatorLive,
        AppNotificationType.recordingExpiring,
        AppNotificationType.freeMinutesLow,
      ]),
    );

    final AppNotification live = page.items.firstWhere(
      (AppNotification item) => item.type == AppNotificationType.creatorLive,
    );
    expect(live.resourceType, 'watch');
    expect(live.resourceId, 'watch_001');
  });

  test('notification preference mock persists V2 switches', () async {
    final MockNotificationPreferencesRepository repository =
        MockNotificationPreferencesRepository(behavior);

    final NotificationPreferences defaults = await repository.getPreferences();
    expect(defaults.creatorLive, isTrue);
    expect(defaults.recordingExpiring, isTrue);
    expect(defaults.freeMinutesLow, isTrue);

    final NotificationPreferences saved = await repository.updatePreferences(
      defaults.copyWith(
        creatorLive: false,
        recordingExpiring: false,
        freeMinutesLow: false,
      ),
    );

    expect(saved.creatorLive, isFalse);
    expect(saved.recordingExpiring, isFalse);
    expect(saved.freeMinutesLow, isFalse);
    expect((await repository.getPreferences()).creatorLive, isFalse);
  });
}
