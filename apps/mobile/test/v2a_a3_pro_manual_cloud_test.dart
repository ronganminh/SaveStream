import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/channels/presentation/pro_manual_record_sheet.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('Q06 manual record sheet offers Cloud only', (
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
    expect(find.text('Local · on this device'), findsNothing);
    expect(find.text('Cloud · on SaveStream servers'), findsOneWidget);
    expect(find.textContaining('5 h'), findsOneWidget);
    final Finder action = find.widgetWithText(
      FilledButton,
      'Record Cloud · use cloud hours',
    );
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
  });

  testWidgets('Q06 disables Cloud record when no cloud hours remain', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(
        ProManualRecordSheet(
          creatorName: 'Lina Studio',
          entitlement: _entitlement(
            localEnabled: false,
            localUnlimited: false,
            cloudMinutes: 0,
          ),
        ),
      ),
    );

    expect(find.text('No cloud hours are available.'), findsOneWidget);
    final Finder action = find.widgetWithText(
      FilledButton,
      'Record Cloud · use cloud hours',
    );
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
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
