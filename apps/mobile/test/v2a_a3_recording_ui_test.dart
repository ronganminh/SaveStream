import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recording_start_sheet.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  final Entitlement entitlement = Entitlement(
    plan: Plan.free,
    hasPurchased: false,
    cloudMinutesAvailable: 0,
    limits: const EntitlementLimits(
      maxWatches: 3,
      maxConcurrentCloudRecordings: 0,
      cloudRetentionDays: 7,
    ),
    watchCount: 1,
    local: LocalEntitlement(
      enabled: true,
      unlimited: false,
      dailyMinutes: 10,
      minutesRemaining: 6,
      resetsAt: DateTime.utc(2026, 10, 5),
      rewardsUsedToday: 2,
      rewardsCapPerDay: 8,
      minutesPerReward: 10,
      extensionsCapPerRecording: 4,
    ),
    updatedAt: DateTime.utc(2026, 10, 4),
  );

  testWidgets('R01 Android shows Local quota, storage and confirmation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocalRecordingStartSheetBody(
            creatorName: 'Lina Studio',
            entitlement: entitlement,
            platform: DevicePlatform.android,
            freeStorageBytes: 18 * 1024 * 1024 * 1024,
            onConfirm: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Record Lina Studio'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('6 / 10 minutes remaining'), findsOneWidget);
    expect(find.textContaining('18.0 GB'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });
}
