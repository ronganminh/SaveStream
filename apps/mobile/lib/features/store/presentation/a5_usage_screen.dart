import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';

/// M01 / M02 — Usage summary for Free and purchased cloud-hours accounts.
class A5UsageScreen extends ConsumerWidget {
  const A5UsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.usageTitle)),
      body: SafeArea(
        child: entitlement.when(
          loading: () => const _UsageSkeleton(),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(entitlementProvider),
            ),
          ),
          data: (Entitlement data) => ListView(
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              SsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      data.hasPurchased
                          ? context.l10n.cloudHoursAvailableTitle
                          : context.l10n.freeUsageTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: SsSpacing.md),
                    if (data.hasPurchased) ...<Widget>[
                      Text(
                        formatMinutesAsHoursMinutes(
                          data.cloudMinutesAvailable,
                          hoursLabel: context.l10n.timeHoursUnit,
                          minutesLabel: context.l10n.timeMinutesUnit,
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        context.l10n.cloudSlotsUsage(
                          0,
                          data.limits.maxConcurrentCloudRecordings,
                        ),
                      ),
                      Text(
                        context.l10n.watchUsage(
                          data.watchCount,
                          data.limits.maxWatches,
                        ),
                      ),
                      Text(
                        context.l10n.cloudRetentionValue(
                          data.limits.cloudRetentionDays,
                        ),
                      ),
                    ] else ...<Widget>[
                      Text(
                        context.l10n.freeMinutesToday(
                          data.local.minutesRemaining,
                          data.local.dailyMinutes,
                        ),
                      ),
                      Text(
                        context.l10n.rewardUsageToday(
                          data.local.rewardsUsedToday,
                          data.local.rewardsCapPerDay,
                        ),
                      ),
                      Text(
                        context.l10n.watchUsage(
                          data.watchCount,
                          data.limits.maxWatches,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageSkeleton extends StatelessWidget {
  const _UsageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[SsSkeleton(height: 180, radius: SsRadii.lg)],
    );
  }
}
