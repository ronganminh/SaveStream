/// H01/H02/H03/H06 — V2 Home states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_semantic_colors.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../channels/domain/models/watch_summary.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import '../../settings/presentation/notification_action_button.dart';
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
    final UserProfile? profile = ref.watch(profileProvider).value;
    final String? profileName = profile?.displayName?.trim();
    final String? profileEmail = profile?.email.trim();
    final String? displayName = profileName != null && profileName.isNotEmpty
        ? profileName
        : profileEmail != null && profileEmail.isNotEmpty
        ? profileEmail.split('@').first
        : null;

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
              badge: dashboard.value == null
                  ? null
                  : SsPlanBadge(plan: dashboard.value!.entitlement.plan),
              actions: <Widget>[const NotificationActionButton()],
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
    final String cloudTime = formatMinutesAsHoursMinutes(
      entitlement.cloudMinutesAvailable,
      hoursLabel: l10n.timeHoursUnit,
      minutesLabel: l10n.timeMinutesUnit,
    );

    return <Widget>[
      const SizedBox(height: SsSpacing.lg),
      SsQuotaCard(
        title: l10n.homeCloudTimeTitle,
        value: cloudTime,
        subtitle: l10n.homeWatchingCapacity(
          data.watches.length,
          entitlement.limits.maxWatches,
        ),
      ),
      if (data.watches.isNotEmpty) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsSectionHeader(
          title: l10n.channelsTitle,
          actionLabel: l10n.sectionExampleAction,
          onAction: () => context.go(AppRoutes.channels),
        ),
        const SizedBox(height: SsSpacing.sm),
        if (data.liveWatches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: SsSpacing.md),
            child: Text(
              l10n.homeNoLiveCreators,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final WatchSummary watch in data.liveWatches.take(1))
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: _HomeLiveCreatorCard(
                watch: watch,
                onRecord: online
                    ? () => context.push(AppRoutes.channelDetail(watch.id))
                    : null,
                onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
              ),
            ),
      ],
      if (data.watches.isNotEmpty && online) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        _HomeProUpsellCard(onTap: () => context.push(AppRoutes.usage)),
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
    final bool cloudExhausted = entitlement.cloudMinutesAvailable <= 0;

    return <Widget>[
      if (cloudExhausted) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsInlineAlert(
          title: l10n.cloudHoursExhaustedTitle,
          message: active == null
              ? l10n.cloudHoursExhaustedBody
              : l10n.cloudHoursExhaustedRecordingBody,
          tone: SsInlineAlertTone.warning,
        ),
        const SizedBox(height: SsSpacing.sm),
        SsPrimaryButton(
          label: l10n.buyMoreCloudHoursAction,
          icon: Icons.add_card_rounded,
          onPressed: () =>
              context.push(AppRoutes.cloudHoursLocation('auto_record')),
        ),
      ],
      if (active != null) ...<Widget>[
        const SizedBox(height: SsSpacing.lg),
        SsActiveRecordingCard(
          creatorName: active.creatorDisplayName,
          elapsed: formatDurationHms(Duration(seconds: active.durationSeconds)),
          engine: Engine.cloud,
          onTap: () => context.push(AppRoutes.recordingDetail(active.id)),
        ),
        const SizedBox(height: SsSpacing.md),
        SsInlineAlert(
          title: l10n.cloudLabel,
          message: l10n.cloudRecordingServerBody,
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
      if (active == null) ...<Widget>[
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
              imageUrl: watch.creatorAvatarUrl,
              onTap: () => context.push(AppRoutes.channelDetail(watch.id)),
            ),
          ),
      ],
    ];
  }
}

class _HomeLiveCreatorCard extends StatelessWidget {
  const _HomeLiveCreatorCard({
    required this.watch,
    required this.onRecord,
    required this.onTap,
  });

  final WatchSummary watch;
  final VoidCallback? onRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String handle = watch.creatorUsername.startsWith('@')
        ? watch.creatorUsername
        : '@${watch.creatorUsername}';
    final DateTime? liveSince = watch.lastLiveAt?.toLocal();
    final String subtitle = liveSince == null
        ? handle
        : '$handle · ${context.l10n.homeLiveSinceLabel(MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(liveSince)))}';

    return SsCard(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                SsAvatar(
                  label: watch.creatorDisplayName,
                  imageUrl: watch.creatorAvatarUrl,
                  radius: 24,
                  isLive: true,
                ),
                const SizedBox(width: SsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        watch.creatorDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: SsSpacing.xs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: SsSpacing.sm),
                const SsLiveBadge(isLive: true),
              ],
            ),
            const SizedBox(height: SsSpacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget storage = Row(
                  children: <Widget>[
                    Icon(
                      Icons.cloud_rounded,
                      size: 20,
                      color: context.semanticColors.cloud,
                    ),
                    const SizedBox(width: SsSpacing.xs),
                    Flexible(
                      child: Text(
                        context.l10n.cloudLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: context.semanticColors.cloud,
                        ),
                      ),
                    ),
                  ],
                );
                final Widget recordButton = FilledButton.icon(
                  onPressed: onRecord,
                  icon: const Icon(Icons.radio_button_checked_rounded),
                  label: Text(context.l10n.recordNowAction),
                );
                final bool stackActions =
                    MediaQuery.textScalerOf(context).scale(1) >= 1.4 ||
                    constraints.maxWidth < 240;
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      storage,
                      const SizedBox(height: SsSpacing.sm),
                      recordButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: storage),
                    const SizedBox(width: SsSpacing.sm),
                    recordButton,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeProUpsellCard extends StatelessWidget {
  const _HomeProUpsellCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: SsRadii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(SsSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: SsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.homeAutoRecordUpsellTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: SsSpacing.xs),
                  Text(
                    context.l10n.homeAutoRecordUpsellBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  TextButton(
                    onPressed: onTap,
                    child: Text(context.l10n.viewProAction),
                  ),
                ],
              ),
            ),
          ],
        ),
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
