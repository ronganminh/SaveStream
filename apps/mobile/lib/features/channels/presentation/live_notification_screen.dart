/// N04b–N04d — Creator LIVE notification deep link.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';

enum LiveNotificationState { checking, live, ended }

class LiveNotificationScreen extends ConsumerWidget {
  const LiveNotificationScreen({
    required this.watchId,
    required this.state,
    super.key,
  });

  final String watchId;
  final LiveNotificationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WatchSummary?> watch = ref.watch(
      watchDetailProvider(watchId),
    );
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: watch.when(
          loading: () => const _LiveNotificationSkeleton(),
          error: (Object error, StackTrace stack) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(watchDetailProvider(watchId)),
            ),
          ),
          data: (WatchSummary? item) {
            if (item == null) {
              return SsEmptyState(
                title: context.l10n.channelNotFoundTitle,
                message: context.l10n.channelNotFoundBody,
                icon: Icons.person_off_outlined,
              );
            }
            return _NotificationBody(watch: item, state: state);
          },
        ),
      ),
    );
  }
}

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({required this.watch, required this.state});

  final WatchSummary watch;
  final LiveNotificationState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.xl),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SsCreatorTile(
                  name: watch.creatorDisplayName,
                  handle: watch.creatorUsername,
                  isLive: state == LiveNotificationState.live,
                ),
                const SizedBox(height: SsSpacing.lg),
                switch (state) {
                  LiveNotificationState.checking => SsInlineAlert(
                    title: context.l10n.liveCheckTitle,
                    message: context.l10n.liveCheckBody,
                    tone: SsInlineAlertTone.info,
                  ),
                  LiveNotificationState.live => SsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SsLiveBadge(isLive: true),
                        const SizedBox(height: SsSpacing.md),
                        Text(context.l10n.creatorLiveSince),
                        const SizedBox(height: SsSpacing.lg),
                        SsPrimaryButton(
                          label: context.l10n.recordNowAction,
                          icon: Icons.fiber_manual_record_rounded,
                          onPressed: () =>
                              context.go(AppRoutes.channelDetail(watch.id)),
                        ),
                      ],
                    ),
                  ),
                  LiveNotificationState.ended => SsInlineAlert(
                    title: context.l10n.liveEndedTitle,
                    message: context.l10n.liveEndedBody(
                      watch.creatorDisplayName,
                    ),
                    tone: SsInlineAlertTone.warning,
                  ),
                },
                if (state == LiveNotificationState.ended) ...<Widget>[
                  const SizedBox(height: SsSpacing.lg),
                  SsPrimaryButton(
                    label: context.l10n.backToHomeAction,
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveNotificationSkeleton extends StatelessWidget {
  const _LiveNotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.xl),
      children: const <Widget>[
        SsSkeleton(height: 96, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 140, radius: SsRadii.lg),
      ],
    );
  }
}

LiveNotificationState liveNotificationStateFromValue(String? value) {
  return switch (value) {
    'live' => LiveNotificationState.live,
    'ended' => LiveNotificationState.ended,
    _ => LiveNotificationState.checking,
  };
}
