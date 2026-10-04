import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/channels/presentation/pro_manual_record_sheet.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_detail_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('Q06 Pro defaults to enabled unlimited Local from server', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        ProManualRecordSheet(
          creatorName: 'Lina Studio',
          entitlement: _entitlement(
            localEnabled: true,
            localUnlimited: true,
            cloudMinutes: 300,
          ),
        ),
      ),
    );

    expect(find.text('Record Lina Studio'), findsOneWidget);
    expect(find.text('Local · on this device'), findsOneWidget);
    expect(find.textContaining('Does not use cloud hours'), findsOneWidget);
    expect(find.text('Record Local'), findsOneWidget);
    expect(find.textContaining('5 h'), findsOneWidget);
  });

  testWidgets('Q06 disables Local when server local.enabled is false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        ProManualRecordSheet(
          creatorName: 'Lina Studio',
          entitlement: _entitlement(
            localEnabled: false,
            localUnlimited: false,
            cloudMinutes: 300,
          ),
        ),
      ),
    );

    expect(
      find.text('Local recording is currently disabled for this account.'),
      findsOneWidget,
    );
    expect(find.text('Record Cloud · use cloud hours'), findsOneWidget);
  });

  testWidgets('R26 cloud active uses server lifecycle copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        CloudRecordingLifecycleCard(
          recording: _recording(
            status: RecordingStatus.recording,
            durationSeconds: 6138,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'SaveStream is recording on the server. '
        'Your phone does not need to stay online.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Playback is not available while recording'),
      findsOneWidget,
    );
  });

  testWidgets('R27 cloud processing is checklist-only with no percent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        CloudRecordingLifecycleCard(
          recording: _recording(
            status: RecordingStatus.processing,
            progress: 0.72,
          ),
        ),
      ),
    );

    expect(find.text('Processing on server'), findsOneWidget);
    expect(find.text('Merge and verify file'), findsOneWidget);
    expect(find.text('Create preview'), findsOneWidget);
    expect(find.text('Ready to play'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('R28 failed cloud recording states server refund policy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        CloudRecordingLifecycleCard(
          recording: _recording(
            status: RecordingStatus.failed,
            durationSeconds: 1152,
            errorMessage: 'Source connection lost.',
          ),
        ),
      ),
    );

    expect(find.text('Cloud recording failed'), findsOneWidget);
    expect(find.textContaining('refunded by the server'), findsOneWidget);
    expect(find.text('Source connection lost.'), findsOneWidget);
  });
}

Entitlement _entitlement({
  required bool localEnabled,
  required bool localUnlimited,
  required int cloudMinutes,
}) {
  return Entitlement(
    plan: Plan.pro,
    hasPurchased: true,
    cloudMinutesAvailable: cloudMinutes,
    limits: const EntitlementLimits(
      maxWatches: 20,
      maxConcurrentCloudRecordings: 3,
      cloudRetentionDays: 30,
    ),
    watchCount: 8,
    local: LocalEntitlement(
      enabled: localEnabled,
      unlimited: localUnlimited,
      dailyMinutes: 0,
      minutesRemaining: 0,
      resetsAt: DateTime.utc(2026, 10, 5),
      rewardsUsedToday: 0,
      rewardsCapPerDay: 8,
      minutesPerReward: 10,
      extensionsCapPerRecording: 4,
    ),
    updatedAt: DateTime.utc(2026, 10, 4),
  );
}

RecordingSummary _recording({
  required RecordingStatus status,
  int durationSeconds = 0,
  double? progress,
  String? errorMessage,
}) {
  return RecordingSummary(
    id: 'rec_cloud',
    creatorDisplayName: 'Lina Studio',
    creatorUsername: '@linastudio',
    status: status,
    actions: RecordingActions(
      canStop: status == RecordingStatus.recording,
      canRetry: status == RecordingStatus.failed,
      canDelete: status == RecordingStatus.failed,
    ),
    startedAt: DateTime.utc(2026, 10, 4, 4),
    durationSeconds: durationSeconds,
    progress: progress,
    errorMessage: errorMessage,
    engine: Engine.cloud,
  );
}
