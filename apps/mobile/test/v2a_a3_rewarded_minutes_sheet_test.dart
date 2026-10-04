import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recording_reward_sheet.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  Widget app({
    required LocalEntitlement entitlement,
    required int extensionsUsed,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RewardedMinutesSheet(
            entitlement: entitlement,
            extensionsUsed: extensionsUsed,
          ),
        ),
      ),
    );
  }

  testWidgets('R06 shows reward offer before starting the ad', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(entitlement: _entitlement(), extensionsUsed: 1),
    );

    expect(find.text('+10 minutes for this recording'), findsOneWidget);
    expect(find.text('Extensions for this recording 1/4'), findsOneWidget);
    expect(find.text('Rewarded ads today 2/8'), findsOneWidget);
    expect(find.text('Watch ad'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });

  testWidgets('R11 blocks after four extensions', (WidgetTester tester) async {
    await tester.pumpWidget(
      app(entitlement: _entitlement(), extensionsUsed: 4),
    );

    expect(find.text('Maximum extensions reached'), findsOneWidget);
    expect(find.text('Watch ad'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('R12 blocks after daily rewarded-ad cap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(entitlement: _entitlement(rewardsUsedToday: 8), extensionsUsed: 2),
    );

    expect(find.text('Daily rewarded-ad limit reached'), findsOneWidget);
    expect(find.text('Watch ad'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });
}

LocalEntitlement _entitlement({int rewardsUsedToday = 2}) {
  return LocalEntitlement(
    enabled: true,
    unlimited: false,
    dailyMinutes: 10,
    minutesRemaining: 1,
    resetsAt: DateTime.utc(2026, 10, 5),
    rewardsUsedToday: rewardsUsedToday,
    rewardsCapPerDay: 8,
    minutesPerReward: 10,
    extensionsCapPerRecording: 4,
  );
}
