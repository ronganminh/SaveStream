import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'channels_screen.dart';
import 'controllers/watch_providers.dart';

class ChannelDetailScreen extends ConsumerWidget {
  const ChannelDetailScreen({required this.watchId, super.key});

  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<WatchSummary?> watch = ref.watch(
      watchDetailProvider(watchId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.channelDetailTitle)),
      body: SafeArea(
        child: watch.when(
          loading: () => Center(child: SsLoadingView(label: l10n.loadingLabel)),
          error: (_, _) => SsErrorState(
            title: l10n.errorTitle,
            message: l10n.errorBody,
            retryLabel: l10n.retryAction,
            onRetry: () => ref.invalidate(watchDetailProvider(watchId)),
          ),
          data: (WatchSummary? value) {
            if (value == null) {
              return SsEmptyState(
                title: l10n.channelNotFoundTitle,
                message: l10n.channelNotFoundBody,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(SsSpacing.lg),
              children: <Widget>[
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SsAvatar(label: value.creatorDisplayName, radius: 28),
                          const SizedBox(width: SsSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  value.creatorDisplayName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(value.creatorUsername),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SsSpacing.xl),
                      SsSectionHeader(title: l10n.watchStatusLabel),
                      SsStatusChip(
                        label: watchStatusLabel(l10n, value.status),
                        tone: watchStatusTone(value.status),
                      ),
                      const SizedBox(height: SsSpacing.md),
                      SsStatusChip(
                        label: value.isLive
                            ? l10n.liveStatus
                            : l10n.offlineStatus,
                        tone: value.isLive
                            ? SsStatusTone.recording
                            : SsStatusTone.neutral,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
