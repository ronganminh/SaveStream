/// H01/H02/H03/H06 — V2 Home states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../channels/presentation/cloud_hours_upsell_sheet.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/home_dashboard_view_model.dart';
import 'controllers/home_dashboard_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<HomeDashboardViewModel> dashboard = ref.watch(
      homeDashboardProvider,
    );
    final bool online = ref.watch(appOnlineProvider).value ?? true;
    final String? displayName = dashboard.value?.metrics.displayName;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SsLargeHeader(
              title: displayName == null
                  ? l10n.appTitle
                  : l10n.homeGreeting(displayName),
              subtitle: MaterialLocalizations.of(
                context,
              ).formatFullDate(DateTime.now()),
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.notificationsTitle,
                  onPressed: () => context.push(AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ],
            ),
            Expanded(
              child: SsAsyncRefreshFrame(
                isRefreshing: dashboard.isRefreshing,
                child: dashboard.when(
                  loading: () => const _HomeSkeleton(),
                  error: (Object error, StackTrace stackTrace) => Center(
                    child: SsAsyncErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(homeDashboardProvider),
                    ),
                  ),
                  data: (HomeDashboardViewModel data) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(homeDashboardProvider);
                      await ref.read(homeDashboardProvider.future);
                    },
                    child: _HomeDashboard(data: data, online: online),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.data, required this.online});

  final HomeDashboardViewModel data;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final Entitlement entitlement = data.entitlement;
    final bool isPro = entitlement.plan == Plan.pro;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        SsSpacing.lg,
        0,
        SsSpacing.lg,
        SsSpacing.xxl,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SsPlanBadge(plan: entitlement.plan),
                ),
                if (!online) ...<Widget>[
                  const SizedBox(height: SsSpacing.md),
                  SsInlineAlert(
                    title: context.l10n.homeOfflineTitle,
                    message: context.l10n.homeOfflineBody,
                    tone: SsInlineAlertTone.warning,
                  ),
                ],
                if (data.watches.isEmpty) ...<Widget>[
                  const SizedBox(height: SsSpacing.xl),
                  SsCard(
                    child: SsEmptyState(
                      icon: Icons.person_add_alt_1_rounded,
                      title: context.l10n.homeEmptyCreatorTitle,
                      message: context.l10n.homeEmptyCreatorBody,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.lg),
                  SsPrimaryButton(
                    label: context.l10n.addChannelAction,
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: online
                        ? () => context.push(AppRoutes.addChannel)
                        : null,
                  ),
                ] else if (isPro) ...<Widget>[
                  ..._buildPro(context, entitlement),
                ] else ...<Widget>[..._buildFree(context, entitlement)],
                if (data.missedNoCloudSlot.isNotEmpty) ...<Widget>[
                  const SizedBox(height: SsSpacing.lg),
                  SsInlineAlert(
                    title: context.l10n.creatorMissedTitle,
                    message: context.l10n.creatorMissedBody,
                    tone: SsInlineAlertTone.warning,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFree(BuildContext context, Entitlement entitlement) {
    final AppLocalizations l10n = context.l10n;
    final LocalEntitlement local = entitlement.local;
    final WatchSummary? live = data.liveWatches.isEmpty
        ? null
        : data.liveWatches.first;
    final int limit = entitlement.limits.maxWatches;
    final int remainingSlots = (limit - data.watches.length)
        .clamp(0, limit)
        .toInt();
    final Duration resetIn = local.resetsAt.difference(DateTime.now().toUtc());
    final String reset = formatResetCountdown(
      resetIn,
      hoursLabel: l10n.timeHoursUnit,
      minutesLabel: l10n.timeMinutesUnit,
    );

    return <Widget>[
      if (live != null) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.homeLiveCreatorTitle(live.creatorDisplayName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SsLiveBadge(isLive: true),
                ],
              ),
              const SizedBox(height: SsSpacing.sm),
              Text(l10n.homeLocalSaveHint),
              const SizedBox(height: SsSpacing.md),
              SsPrimaryButton(
                label: l10n.recordNowAction,
                icon: Icons.fiber_manual_record_rounded,
                onPressed: online
                    ? () => context.push(AppRoutes.channelDetail(live.id))
                    : null,
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: SsSpacing.lg),
      SsQuotaCard(
        title: local.minutesRemaining > 0
            ? l10n.homeFreeMinutesTitle
            : l10n.homeMinutesExhaustedTitle,
        value: l10n.homeFreeMinutesRemaining(
          local.minutesRemaining,
          local.dailyMinutes,
        ),
        subtitle:
            '${l10n.homeResetAfter(reset)} · ${l10n.homeRewardsUsed(local.rewardsUsedToday, local.rewardsCapPerDay)}',
        progress: local.dailyMinutes == 0
            ? 0
            : local.minutesRemaining / local.dailyMinutes,
      ),
      if (local.minutesRemaining == 0) ...<Widget>[
        const SizedBox(height: SsSpacing.md),
        SsInlineAlert(
          title: l10n.homeMinutesExhaustedTitle,
          message: l10n.homeMinutesExhaustedBody,
          tone: SsInlineAlertTone.warning,
        ),
        const SizedBox(height: SsSpacing.sm),
        SsPrimaryButton(
          label: l10n.watchAdMinutesAction(local.minutesPerReward),
          onPressed: live == null || !online
              ? null
              : () => context.push(AppRoutes.channelDetail(live.id)),
        ),
      ],
      const SizedBox(height: SsSpacing.lg),
      _WatchingSummary(
        count: data.watches.length,
        limit: limit,
        detail: remainingSlots > 0
            ? l10n.watchCapacityRemaining(remainingSlots)
            : l10n.watchCapacityFull,
      ),
      if (data.liveWatches.isNotEmpty) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsSectionHeader(
          title: l10n.channelsTitle,
          actionLabel: l10n.sectionExampleAction,
          onAction: () => context.go(AppRoutes.channels),
        ),
        const SizedBox(height: SsSpacing.sm),
        for (final WatchSummary watch in data.liveWatches.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: SsSpacing.sm),
            child: SsCreatorTile(
              name: watch.creatorDisplayName,
              handle: watch.creatorUsername,
              isLive: true,
              onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
            ),
          ),
      ],
      if (data.hasAhaMoment &&
          local.minutesRemaining > 0 &&
          online) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.homeAutoRecordUpsellTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsSpacing.sm),
              Text(l10n.homeAutoRecordUpsellBody),
              const SizedBox(height: SsSpacing.md),
              SsSecondaryButton(
                label: l10n.buyCloudHoursAction,
                icon: Icons.cloud_outlined,
                onPressed: () => showCloudHoursUpsellSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.lg),
        SsBannerAdSlot(label: l10n.advertisementLabel),
      ],
    ];
  }

  List<Widget> _buildPro(BuildContext context, Entitlement entitlement) {
    final AppLocalizations l10n = context.l10n;
    final String cloudTime = formatMinutesAsHoursMinutes(
      entitlement.cloudMinutesAvailable,
      hoursLabel: l10n.timeHoursUnit,
      minutesLabel: l10n.timeMinutesUnit,
    );
    final RecordingSummary? active = data.activeRecordings.isEmpty
        ? null
        : data.activeRecordings.first;

    return <Widget>[
      if (active != null) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsActiveRecordingCard(
          creatorName: active.creatorDisplayName,
          elapsed: formatDurationHms(Duration(seconds: active.durationSeconds)),
          engine: Engine.cloud,
          onTap: () => context.push(AppRoutes.recordingDetail(active.id)),
        ),
      ],
      const SizedBox(height: SsSpacing.lg),
      SsQuotaCard(
        title: l10n.homeCloudTimeTitle,
        value: cloudTime,
        subtitle:
            '${l10n.homeCloudSlots(data.cloudSlotsUsed, entitlement.limits.maxConcurrentCloudRecordings)} · '
            '${l10n.homeWatchingCapacity(data.watches.length, entitlement.limits.maxWatches)}',
      ),
      const SizedBox(height: SsSpacing.sm),
      Text(
        l10n.homeCloudRetention(entitlement.limits.cloudRetentionDays),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (data.waitingForCloudSlot.isNotEmpty) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsInlineAlert(
          title: l10n.watchWaitingCloudSlot,
          message: l10n.creatorWaitingBody(
            entitlement.limits.maxConcurrentCloudRecordings,
          ),
          tone: SsInlineAlertTone.info,
        ),
      ],
      const SizedBox(height: SsSpacing.lg),
      SsSectionHeader(
        title: l10n.channelsTitle,
        actionLabel: l10n.sectionExampleAction,
        onAction: () => context.go(AppRoutes.channels),
      ),
      const SizedBox(height: SsSpacing.sm),
      for (final WatchSummary watch in data.featuredWatches)
        Padding(
          padding: const EdgeInsets.only(bottom: SsSpacing.sm),
          child: SsCreatorTile(
            name: watch.creatorDisplayName,
            handle: watch.creatorUsername,
            isLive: watch.isLive,
            onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
          ),
        ),
    ];
  }
}

class _WatchingSummary extends StatelessWidget {
  const _WatchingSummary({
    required this.count,
    required this.limit,
    required this.detail,
  });

  final int count;
  final int limit;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.homeWatchingCapacity(count, limit),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.xs),
          Text(detail),
          const SizedBox(height: SsSpacing.md),
          LinearProgressIndicator(
            value: limit == 0 ? 0 : (count / limit).clamp(0.0, 1.0).toDouble(),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(width: 90, height: 28, radius: SsRadii.pill),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 164, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 132, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 96, radius: SsRadii.lg),
      ],
    );
  }
}
