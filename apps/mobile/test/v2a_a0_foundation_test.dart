import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/formatters/v2_formatters.dart';
import 'package:savestream_mobile/core/mock/mock_scenario.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/mock_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/rewards/data/repositories/mock_reward_repository.dart';
import 'package:savestream_mobile/features/rewards/domain/models/reward.dart';
import 'package:savestream_mobile/features/store/data/repositories/mock_store_repository.dart';

void main() {
  const MockBehavior behavior = MockBehavior(
    scenario: MockScenario.success,
    latency: Duration.zero,
  );

  test('A0 entitlement mock exposes Free and Pro variants', () async {
    final Entitlement free = await const MockEntitlementRepository(
      behavior,
      state: EntitlementMockState.free,
    ).getEntitlement();
    final Entitlement pro = await const MockEntitlementRepository(
      behavior,
      state: EntitlementMockState.pro,
    ).getEntitlement();

    expect(free.plan, Plan.free);
    expect(free.local.minutesRemaining, 6);
    expect(pro.plan, Plan.pro);
    expect(pro.local.unlimited, isTrue);
    expect(pro.limits.maxConcurrentCloudRecordings, 3);
  });

  test('A0 reward mock validates created reward on status poll', () async {
    final MockRewardRepository repository = MockRewardRepository(behavior);
    final Reward reward = await repository.create(
      purpose: RewardPurpose.localMinutes,
    );
    expect(reward.status, RewardStatus.pending);
    expect((await repository.getStatus(reward.rewardId)).status, RewardStatus.valid);
  });

  test('A0 store packages match V2 purchased-hour products', () async {
    final List packages = await const MockStoreRepository(behavior).listPackages();
    expect(packages.map((dynamic p) => p.cloudMinutes), <int>[3000, 9000, 24000]);
  });

  test('A0 formatters use minutes and HH:MM:SS', () {
    expect(
      formatMinutesAsHoursMinutes(
        8000,
        hoursLabel: 'hours',
        minutesLabel: 'minutes',
      ),
      '133 hours 20 minutes',
    );
    expect(formatDurationHms(const Duration(seconds: 3723)), '01:02:03');
  });

  testWidgets('A0 shared widgets render location, quota, alert and checklist',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                SsLocationChip(engine: Engine.local),
                SsPlanBadge(plan: Plan.pro),
                SsLiveBadge(isLive: true),
                SsQuotaCard(
                  title: 'Cloud time',
                  value: '50 hours',
                  progress: .5,
                ),
                SsInlineAlert(
                  title: 'Warning',
                  tone: SsInlineAlertTone.warning,
                ),
                SsChecklist(
                  items: <SsChecklistItem>[
                    SsChecklistItem(label: 'Finalize', done: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Local'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('50 hours'), findsOneWidget);
    expect(find.text('Finalize'), findsOneWidget);
  });
}
