/// W15 — Pro auto-record settings.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/watch_summary.dart';
import 'cloud_hours_upsell_sheet.dart';
import 'controllers/watch_providers.dart';

class AutoRecordSettingsScreen extends ConsumerStatefulWidget {
  const AutoRecordSettingsScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<AutoRecordSettingsScreen> createState() =>
      _AutoRecordSettingsScreenState();
}

class _AutoRecordSettingsScreenState
    extends ConsumerState<AutoRecordSettingsScreen> {
  bool _mutating = false;

  Future<void> _toggle(bool enabled) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await ref
          .read(watchControllerProvider)
          .setAutoRecord(widget.watchId, enabled: enabled);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WatchSummary?> watch = ref.watch(
      watchDetailProvider(widget.watchId),
    );
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AsyncValue<List<RecordingSummary>> recordings = ref.watch(
      watchRecordingsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.autoRecordSettingsTitle)),
      body: SafeArea(child: _body(watch, entitlement, recordings)),
    );
  }

  Widget _body(
    AsyncValue<WatchSummary?> watch,
    AsyncValue<Entitlement> entitlement,
    AsyncValue<List<RecordingSummary>> recordings,
  ) {
    if (watch.isLoading || entitlement.isLoading || recordings.isLoading) {
      return const _AutoRecordSkeleton();
    }
    if (watch.hasError || entitlement.hasError || recordings.hasError) {
      final Object error =
          watch.error ?? entitlement.error ?? recordings.error!;
      return Center(
        child: SsAsyncErrorState(
          error: error,
          onRetry: () {
            ref.invalidate(watchDetailProvider(widget.watchId));
            ref.invalidate(entitlementProvider);
            ref.invalidate(watchRecordingsProvider);
          },
        ),
      );
    }
    final WatchSummary? item = watch.requireValue;
    if (item == null) {
      return SsEmptyState(
        title: context.l10n.channelNotFoundTitle,
        message: context.l10n.channelNotFoundBody,
        icon: Icons.person_off_outlined,
      );
    }
    final Entitlement access = entitlement.requireValue;
    if (access.plan != Plan.pro) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SsSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline_rounded, size: 56),
                const SizedBox(height: SsSpacing.lg),
                Text(
                  context.l10n.cloudHoursUpsellTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SsSpacing.sm),
                Text(
                  context.l10n.cloudHoursUpsellBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: SsSpacing.xl),
                SsPrimaryButton(
                  label: context.l10n.buyCloudHoursAction,
                  onPressed: () => showCloudHoursUpsellSheet(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int activeCloud = recordings.requireValue
        .where(
          (RecordingSummary recording) =>
              recording.engine == Engine.cloud &&
              recording.status == RecordingStatus.recording,
        )
        .length;
    final String cloudTime = formatMinutesAsHoursMinutes(
      access.cloudMinutesAvailable,
      hoursLabel: context.l10n.timeHoursUnit,
      minutesLabel: context.l10n.timeMinutesUnit,
    );

    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SsCard(
                  child: Row(
                    children: <Widget>[
                      SsAvatar(label: item.creatorDisplayName, radius: 24),
                      const SizedBox(width: SsSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.creatorDisplayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(item.creatorUsername),
                          ],
                        ),
                      ),
                      const SsPlanBadge(plan: Plan.pro),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.lg),
                SsCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item.autoRecord,
                    title: Text(context.l10n.autoRecordWhenLive),
                    subtitle: Text(context.l10n.autoRecordCloudLocation),
                    secondary: const Icon(Icons.bolt_rounded),
                    onChanged: _mutating ? null : _toggle,
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                SsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SsLocationChip(
                        engine: Engine.cloud,
                        label: context.l10n.cloudLabel,
                      ),
                      const SizedBox(height: SsSpacing.md),
                      Text(
                        context.l10n.cloudRetentionValue(
                          access.limits.cloudRetentionDays,
                        ),
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        context.l10n.cloudConcurrentValue(
                          activeCloud,
                          access.limits.maxConcurrentCloudRecordings,
                        ),
                      ),
                      const SizedBox(height: SsSpacing.sm),
                      Text(context.l10n.cloudTimeRemainingValue(cloudTime)),
                    ],
                  ),
                ),
                const SizedBox(height: SsSpacing.md),
                SsInlineAlert(
                  title: context.l10n.watchWaitingCloudSlot,
                  message: context.l10n.cloudQueueInfo,
                  tone: SsInlineAlertTone.info,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AutoRecordSkeleton extends StatelessWidget {
  const _AutoRecordSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 96, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 92, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.md),
        SsSkeleton(height: 160, radius: SsRadii.lg),
      ],
    );
  }
}
