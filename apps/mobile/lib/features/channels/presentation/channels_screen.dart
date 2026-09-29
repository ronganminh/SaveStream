import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/mock/mock_repository_base.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<WatchSummary>> watches = ref.watch(watchListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelsTitle)),
      body: SafeArea(
        child: watches.when(
          loading: () => Center(child: SsLoadingView(label: l10n.loadingLabel)),
          error: (Object error, StackTrace stackTrace) => SsErrorState(
            title: _errorTitle(l10n, error),
            message: _errorMessage(l10n, error),
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(watchListProvider),
          ),
          data: (List<WatchSummary> items) {
            if (items.isEmpty) {
              return SsEmptyState(
                title: l10n.emptyChannelsTitle,
                message: l10n.emptyChannelsBody,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(SsSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: SsSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final WatchSummary watch = items[index];
                return SsCard(
                  child: SsListTile(
                    title: watch.creatorDisplayName,
                    subtitle: watch.creatorUsername,
                    leading: SsAvatar(label: watch.creatorDisplayName),
                    trailing: SsStatusChip(
                      label: watchStatusLabel(l10n, watch.status),
                      tone: watchStatusTone(watch.status),
                      icon: watch.isLive
                          ? Icons.fiber_manual_record_rounded
                          : null,
                    ),
                    onTap: () =>
                        context.push(AppRoutes.channelDetail(watch.id)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

String watchStatusLabel(AppLocalizations l10n, WatchStatus status) {
  return switch (status) {
    WatchStatus.active => l10n.watchStatusActive,
    WatchStatus.paused => l10n.watchStatusPaused,
    WatchStatus.pausedInsufficientCredit =>
      l10n.watchStatusPausedInsufficientCredit,
    WatchStatus.pausedError => l10n.watchStatusPausedError,
    WatchStatus.disabled => l10n.watchStatusDisabled,
  };
}

SsStatusTone watchStatusTone(WatchStatus status) {
  return switch (status) {
    WatchStatus.active => SsStatusTone.success,
    WatchStatus.paused => SsStatusTone.warning,
    WatchStatus.pausedInsufficientCredit => SsStatusTone.warning,
    WatchStatus.pausedError => SsStatusTone.error,
    WatchStatus.disabled => SsStatusTone.neutral,
  };
}

String _errorTitle(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorTitle;
  }
  return l10n.errorTitle;
}

String _errorMessage(AppLocalizations l10n, Object error) {
  if (error is MockRepositoryException &&
      error.kind == MockFailureKind.offlineLike) {
    return l10n.offlineErrorBody;
  }
  return l10n.errorBody;
}
