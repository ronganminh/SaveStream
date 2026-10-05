import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/push_service.dart';
import '../domain/models/app_notification.dart';
import '../domain/models/notification_preferences.dart';
import 'controllers/notification_feed_providers.dart';
import 'controllers/notification_preferences_providers.dart';
import 'controllers/push_permission_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final String? recordingId = notification.recordingId;
    if (recordingId != null) {
      context.push(AppRoutes.recordingDetail(recordingId));
    }
    if (notification.read) return;
    try {
      await ref
          .read(notificationFeedProvider.notifier)
          .markRead(notification.id);
    } on Object {
      if (!context.mounted) return;
      SsSnackbar.show(context, context.l10n.notificationMarkReadFailed);
    }
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences next,
  ) async {
    final bool saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .save(next);
    if (saved || !context.mounted) return;
    SsSnackbar.show(context, context.l10n.notificationPreferencesSaveFailed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<NotificationPreferences> preferences = ref.watch(
      notificationPreferencesProvider,
    );
    final AsyncValue<NotificationFeedState> feed = ref.watch(
      notificationFeedProvider,
    );
    final AsyncValue<PushPermissionStatus> pushPermission = ref.watch(
      pushPermissionProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationPreferencesProvider);
            ref.invalidate(notificationFeedProvider);
            await Future.wait<Object?>(<Future<Object?>>[
              ref.read(notificationPreferencesProvider.future),
              ref.read(notificationFeedProvider.future),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              Text(
                l10n.notificationsReleaseBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: SsSpacing.lg),
              Text(
                l10n.notificationPermissionTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsSpacing.sm),
              pushPermission.when(
                loading: () =>
                    const SsSkeleton(height: 88, radius: SsRadii.lg),
                error: (Object error, StackTrace stackTrace) =>
                    SsAsyncErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(pushPermissionProvider),
                    ),
                data: (PushPermissionStatus status) {
                  if (status == PushPermissionStatus.granted) {
                    return SsInlineAlert(
                      title: l10n.notificationPermissionGrantedTitle,
                      message: l10n.notificationPermissionGrantedBody,
                    );
                  }
                  if (status == PushPermissionStatus.denied) {
                    return SsInlineAlert(
                      title: l10n.notificationPermissionDeniedTitle,
                      message: l10n.notificationPermissionDeniedBody,
                      tone: SsInlineAlertTone.warning,
                    );
                  }
                  return SsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(l10n.notificationPermissionPromptBody),
                        const SizedBox(height: SsSpacing.md),
                        SsPrimaryButton(
                          label: l10n.notificationPermissionEnableAction,
                          onPressed: () =>
                              ref.read(pushPermissionProvider.notifier).request(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: SsSpacing.lg),
              Text(
                l10n.notificationPreferencesTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsSpacing.sm),
              preferences.when(
                loading: () =>
                    const SsSkeleton(height: 180, radius: SsRadii.lg),
                error: (Object error, StackTrace stackTrace) =>
                    SsAsyncErrorState(
                      error: error,
                      onRetry: () =>
                          ref.invalidate(notificationPreferencesProvider),
                    ),
                data: (NotificationPreferences value) => SsCard(
                  child: Column(
                    children: <Widget>[
                      _PreferenceSwitch(
                        title: l10n.notificationCreatorLiveTitle,
                        value: value.creatorLive,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(creatorLive: enabled),
                        ),
                      ),
                      const Divider(),
                      _PreferenceSwitch(
                        title: l10n.notificationRecordingExpiringTitle,
                        value: value.recordingExpiring,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(recordingExpiring: enabled),
                        ),
                      ),
                      const Divider(),
                      _PreferenceSwitch(
                        title: l10n.notificationFreeMinutesLowTitle,
                        value: value.freeMinutesLow,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(freeMinutesLow: enabled),
                        ),
                      ),
                      const Divider(),
                      _PreferenceSwitch(
                        title: l10n.notificationRecordingStartedTitle,
                        value: value.recordingStarted,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(recordingStarted: enabled),
                        ),
                      ),
                      const Divider(),
                      _PreferenceSwitch(
                        title: l10n.notificationRecordingReadyTitle,
                        value: value.recordingReady,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(recordingReady: enabled),
                        ),
                      ),
                      const Divider(),
                      _PreferenceSwitch(
                        title: l10n.notificationRecordingFailedTitle,
                        value: value.recordingFailed,
                        onChanged: (bool enabled) => _save(
                          context,
                          ref,
                          value.copyWith(recordingFailed: enabled),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SsSpacing.sm),
              Text(
                l10n.notificationsInAppOnlyBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: SsSpacing.xl),
              Text(
                l10n.notificationHistoryTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SsSpacing.sm),
              feed.when(
                loading: () => const Column(
                  children: <Widget>[
                    SsSkeleton(height: 92, radius: SsRadii.lg),
                    SizedBox(height: SsSpacing.sm),
                    SsSkeleton(height: 92, radius: SsRadii.lg),
                  ],
                ),
                error: (Object error, StackTrace stackTrace) =>
                    SsAsyncErrorState(
                      error: error,
                      onRetry: () => ref.invalidate(notificationFeedProvider),
                    ),
                data: (NotificationFeedState data) {
                  if (data.items.isEmpty) {
                    return SsCard(
                      child: SsEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: l10n.notificationHistoryEmptyTitle,
                        message: l10n.notificationHistoryEmptyBody,
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final AppNotification item in data.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: SsSpacing.sm),
                          child: _NotificationCard(
                            item: item,
                            onTap: () => _open(context, ref, item),
                          ),
                        ),
                      if (data.loadMoreError != null)
                        SsInlineAsyncError(
                          error: data.loadMoreError!,
                          messageOverride: l10n.notificationLoadMoreFailed,
                        ),
                      if (data.hasMore)
                        SsSecondaryButton(
                          label: l10n.loadMoreAction,
                          onPressed: data.isLoadingMore
                              ? null
                              : () => ref
                                    .read(notificationFeedProvider.notifier)
                                    .loadMore(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final IconData icon = switch (item.type) {
      AppNotificationType.recordingStarted => Icons.fiber_manual_record_rounded,
      AppNotificationType.recordingReady => Icons.check_circle_outline_rounded,
      AppNotificationType.recordingFailed => Icons.error_outline_rounded,
      AppNotificationType.other => Icons.notifications_none_rounded,
    };
    return SsCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SsRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: colors.primary),
              const SizedBox(width: SsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        if (!item.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: SsSpacing.xs),
                    Text(item.body),
                    const SizedBox(height: SsSpacing.xs),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(item.createdAt.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
