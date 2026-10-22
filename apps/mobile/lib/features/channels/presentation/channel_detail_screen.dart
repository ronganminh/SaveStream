/// AChannelRecording · AChannelWaiting · AChannelPaused · AChannelUnverified ·
/// AChannelRemove — one channel, its state, settings and removal.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/ss_feedback.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../recordings/domain/models/recording_summary.dart';
import '../../recordings/presentation/controllers/recording_providers.dart';
import '../domain/models/channel_detail_view_model.dart';
import '../domain/models/channel_verification.dart';
import '../domain/models/watch_summary.dart';
import 'channel_v2_parts.dart';
import 'controllers/watch_providers.dart';

enum _MenuAction { pause, resume, remove }

class ChannelDetailScreen extends ConsumerStatefulWidget {
  const ChannelDetailScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<ChannelDetailScreen> createState() =>
      _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends ConsumerState<ChannelDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        final AppLocalizations l10n = context.l10n;
        SsSnackbar.show(
          context,
          error is ApiException && error.statusCode == 403
              ? l10n.v2AutoRecordNeedsMinutes
              : l10n.v2ActionFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(WatchSummary watch) async {
    final bool confirmed =
        await showRemoveChannelDialog(context, handle: channelHandle(watch)) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(() async {
      await ref.read(watchControllerProvider).delete(watch.id);
      if (mounted) context.go(AppRoutes.channels);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.channels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ChannelDetailViewModel?> detail = ref.watch(
      channelDetailProvider(widget.watchId),
    );
    final WatchSummary? watch = detail.value?.watch;
    final WatchController controller = ref.read(watchControllerProvider);

    return SsV2Page(
      safeBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ChannelsTopBar(
            onBack: _back,
            actions: <Widget>[
              if (watch != null)
                PopupMenuButton<_MenuAction>(
                  tooltip: l10n.v2ChannelOptions,
                  icon: SsV2Icon(
                    SsV2IconGlyph.more,
                    color: SsV2Palette.of(context).text,
                  ),
                  onSelected: (_MenuAction action) => switch (action) {
                    _MenuAction.pause => _run(() => controller.pause(watch.id)),
                    _MenuAction.resume => _run(
                      () => controller.resume(watch.id),
                    ),
                    _MenuAction.remove => _remove(watch),
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_MenuAction>>[
                        if (watch.status == WatchStatus.active ||
                            watch.status ==
                                WatchStatus.pausedInsufficientCredit)
                          PopupMenuItem<_MenuAction>(
                            value: _MenuAction.pause,
                            child: Text(l10n.v2PauseWatching),
                          )
                        else
                          PopupMenuItem<_MenuAction>(
                            value: _MenuAction.resume,
                            child: Text(l10n.v2ResumeWatching),
                          ),
                        PopupMenuItem<_MenuAction>(
                          value: _MenuAction.remove,
                          child: Text(l10n.v2RemoveChannel),
                        ),
                      ],
                ),
            ],
          ),
          Expanded(
            child: detail.when(
              skipLoadingOnRefresh: true,
              skipLoadingOnReload: true,
              loading: () => Center(
                child: Semantics(
                  label: l10n.v2LoadingLabel,
                  child: const SsV2Spinner(),
                ),
              ),
              error: (Object error, StackTrace stackTrace) =>
                  ChannelsCenteredMessage(
                    glyph: SsV2IconGlyph.alert,
                    title: l10n.v2ChannelLoadError,
                    body: l10n.v2ChannelsErrorBody,
                    actionWidth: 200,
                    action: SsV2Button(
                      label: l10n.v2RetryShort,
                      variant: SsV2ButtonVariant.outlined,
                      onPressed: () =>
                          ref.invalidate(channelDetailProvider(widget.watchId)),
                    ),
                  ),
              data: (ChannelDetailViewModel? data) => data == null
                  ? ChannelsCenteredMessage(
                      glyph: SsV2IconGlyph.channels,
                      title: l10n.v2ChannelGone,
                      body: l10n.v2ChannelsIntro,
                      actionWidth: 240,
                      action: SsV2Button(
                        label: l10n.v2NavChannels,
                        onPressed: () => context.go(AppRoutes.channels),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(channelDetailProvider(widget.watchId));
                        await ref.read(
                          channelDetailProvider(widget.watchId).future,
                        );
                      },
                      child: _DetailBody(
                        data: data,
                        busy: _busy,
                        now: ref.watch(homeClockProvider),
                        onRun: _run,
                        onRemove: () => _remove(data.watch),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({
    required this.data,
    required this.busy,
    required this.now,
    required this.onRun,
    required this.onRemove,
  });

  final ChannelDetailViewModel data;
  final bool busy;
  final DateTime Function() now;
  final Future<void> Function(Future<void> Function() action) onRun;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final WatchSummary watch = data.watch;
    final String handle = channelHandle(watch);
    final List<RecordingSummary> liveRecordings =
        ref.watch(watchRecordingsProvider).value ?? data.recordings;
    final RecordingSummary? recording =
        activeRecordingFor(watch, data.recordings) ??
        activeRecordingFor(watch, liveRecordings);
    final ChannelState state = channelStateOf(watch, recording: recording);
    final bool verified = watch.isOwnerVerified;
    final WatchController controller = ref.read(watchControllerProvider);
    final Entitlement? entitlement = ref.watch(entitlementProvider).value;

    final List<Widget> chips = <Widget>[
      switch (state) {
        ChannelState.recording => SsV2StatusChip(
          label: l10n.v2ChipLiveRecording,
          tone: SsV2ChipTone.recording,
        ),
        ChannelState.unverified => SsV2StatusChip(
          label: l10n.v2ChipUnverified,
          tone: SsV2ChipTone.paused,
          dot: true,
        ),
        ChannelState.liveNotRecording => SsV2StatusChip(
          label: l10n.v2ChipLiveNotRecording,
          tone: SsV2ChipTone.liveNotRecording,
          dot: true,
        ),
        ChannelState.paused || ChannelState.noMinutes => SsV2StatusChip(
          label: l10n.v2ChipPaused,
          tone: SsV2ChipTone.paused,
          dot: true,
        ),
        ChannelState.waiting => SsV2StatusChip(
          label: l10n.v2ChipWaitingForLive,
          tone: SsV2ChipTone.waiting,
          dot: true,
        ),
      },
      if (verified)
        SsV2StatusChip(
          label: l10n.v2ChipOwnerVerified,
          tone: SsV2ChipTone.success,
        )
      else
        SsV2StatusChip(
          label: l10n.v2ChipNotVerifiedYet,
          tone: SsV2ChipTone.neutral,
        ),
    ];

    final Widget stateCard = switch (state) {
      ChannelState.recording => _RecordingCard(
        watch: watch,
        recording: recording,
        minutesLeft: entitlement?.cloudMinutesAvailable,
        now: now,
        busy: busy,
        onStop: () {
          final String? id = recording?.id ?? watch.activeRecordingId;
          if (id == null) return;
          onRun(() => ref.read(recordingControllerProvider).stop(id));
        },
      ),
      ChannelState.unverified => _UnverifiedBanner(watch: watch, now: now),
      ChannelState.liveNotRecording => SsV2Banner(
        tone: SsV2Tone.error,
        title: l10n.v2LiveNotRecordingTitle(handle),
        actions: <Widget>[if (channelOutOfMinutes(watch)) _BuyMinutesButton()],
        child: Text(
          channelOutOfMinutes(watch)
              ? l10n.v2LiveNotRecordingNoMinutes
              : !watch.autoRecord
              ? l10n.v2LiveNotRecordingAutoOff
              : watch.autoRecordState == AutoRecordState.waitingForCloudSlot
              ? l10n.v2LiveWaitingForSlot
              : l10n.v2LiveNotRecordingStarting,
        ),
      ),
      ChannelState.noMinutes => SsV2Banner(
        tone: SsV2Tone.error,
        title: l10n.v2OutTitle,
        actions: <Widget>[_BuyMinutesButton()],
        child: Text(l10n.v2OutBody),
      ),
      ChannelState.paused => SsV2Banner(
        tone: SsV2Tone.warning,
        title: l10n.v2PausedTitle,
        actions: <Widget>[
          SsV2Button(
            label: l10n.v2ResumeWatching,
            size: SsV2ButtonSize.small,
            expand: false,
            isLoading: busy,
            onPressed: () => onRun(() => controller.resume(watch.id)),
          ),
        ],
        child: Text(l10n.v2PausedBody),
      ),
      ChannelState.waiting => const _WaitingCard(),
    };

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: <Widget>[
                SsV2Avatar(
                  name: handle,
                  size: 88,
                  fontSize: 31,
                  liveRing:
                      state == ChannelState.recording ||
                      state == ChannelState.liveNotRecording,
                ),
                const SizedBox(height: 10),
                Text(
                  handle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: chips,
                ),
              ],
            ),
          ),
          stateCard,
          if (verified) _Stats(watch: watch, recordings: data.recordings),
          SsV2Card(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: <Widget>[
                SsV2SwitchRow(
                  title: l10n.v2AutoRecordWhenLive,
                  subtitle: verified
                      ? l10n.v2UsesRecordingMinutes
                      : l10n.v2AvailableAfterVerification,
                  value: watch.autoRecord,
                  onChanged: verified && !busy
                      ? (bool value) => onRun(
                          () => controller.setAutoRecord(
                            watch.id,
                            enabled: value,
                          ),
                        )
                      : null,
                ),
                Container(height: 1, color: palette.divider),
                SsV2SwitchRow(
                  title: l10n.v2LiveAlerts,
                  value: watch.notifyOnLive,
                  onChanged: verified && !busy
                      ? (bool value) => onRun(
                          () => controller.setNotifyOnLive(
                            watch.id,
                            enabled: value,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: busy ? null : onRemove,
              style: TextButton.styleFrom(
                foregroundColor: palette.errorText,
                padding: const EdgeInsets.all(12),
                textStyle: const TextStyle(
                  fontFamily: SsTypography.uiFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.v2RemoveChannel),
            ),
          ),
        ], 14),
      ),
    );
  }
}

class _BuyMinutesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SsV2Button(
      label: context.l10n.v2BuyMinutes,
      size: SsV2ButtonSize.small,
      expand: false,
      onPressed: () => context.push(AppRoutes.usage),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.watch,
    required this.recording,
    required this.minutesLeft,
    required this.now,
    required this.busy,
    required this.onStop,
  });

  final WatchSummary watch;
  final RecordingSummary? recording;
  final int? minutesLeft;
  final DateTime Function() now;
  final bool busy;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? started = recording?.startedAt;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.errorBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          Text(
            l10n.v2RecordingInTheCloud,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.errorText,
            ),
          ),
          Text(
            l10n.v2SafeToClose,
            style: TextStyle(fontSize: 13, color: palette.liveText),
          ),
          if (started != null)
            RecordingElapsedBuilder(
              startedAt: started,
              now: now,
              builder: (BuildContext context, int seconds) {
                // Billing is per started minute.
                final int used = math.max(
                  recording?.minutesCharged ?? 0,
                  (seconds + 59) ~/ 60,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      formatRecordingClock(seconds),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (minutesLeft != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        l10n.v2MinutesUsedLeft(
                          used,
                          formatRecordingMinutes(l10n, minutesLeft!),
                        ),
                        style: TextStyle(fontSize: 13, color: palette.liveText),
                      ),
                    ],
                  ],
                );
              },
            ),
          OutlinedButton(
            onPressed: busy ? null : onStop,
            style: OutlinedButton.styleFrom(
              backgroundColor: palette.surface,
              foregroundColor: palette.errorText,
              minimumSize: const Size(double.infinity, 52),
              fixedSize: const Size.fromHeight(52),
              side: BorderSide(color: palette.errorBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontFamily: SsTypography.uiFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l10n.v2StopRecording),
          ),
        ], 12),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.infoBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SsV2Icon(SsV2IconGlyph.clock, size: 22, color: palette.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.v2WaitingTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.v2WaitingBody,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnverifiedBanner extends ConsumerWidget {
  const _UnverifiedBanner({required this.watch, required this.now});

  final WatchSummary watch;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ChannelVerification? pending = ref
        .watch(channelVerificationProvider(watch.id))
        .value;
    final DateTime current = now();
    final String? code = pending == null || pending.isExpiredAt(current)
        ? null
        : pending.code;
    // A channel added before verification existed may record until its
    // server-set verification_due_at.
    final DateTime? due = watch.verificationDueAt;
    final String? deadline = due != null && due.isAfter(current)
        ? DateFormat.MMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(due.toLocal())
        : null;
    return SsV2Banner(
      tone: SsV2Tone.warning,
      glyph: SsV2IconGlyph.shield,
      title: l10n.v2FinishVerifyingTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            code == null
                ? l10n.v2FinishVerifyingBody
                : l10n.v2FinishVerifyingBodyCode(code),
          ),
          if (deadline != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              l10n.v2VerifyByDate(deadline),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 10),
          SsV2Button(
            key: const ValueKey<String>('channel-continue-verification'),
            label: l10n.v2ContinueVerification,
            size: SsV2ButtonSize.small,
            onPressed: () => context.push(AppRoutes.channelVerify(watch.id)),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.watch, required this.recordings});

  final WatchSummary watch;
  final List<RecordingSummary> recordings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final int seconds = recordings.fold<int>(
      0,
      (int sum, RecordingSummary item) => sum + item.durationSeconds,
    );
    final String recorded = seconds >= 3600
        ? l10n.v2DurationHours(seconds ~/ 3600)
        : l10n.v2DurationMinutes(seconds ~/ 60);
    final DateTime? last = watch.lastLiveAt?.toLocal();
    final String lastLive = last == null
        ? l10n.v2StatNone
        : DateFormat.MMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(last);
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatTile(
            value: '${recordings.length}',
            label: l10n.v2StatRecordings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(value: recorded, label: l10n.v2StatRecorded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(value: lastLive, label: l10n.v2StatLastLive),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

/// AChannelRemove: "Remove @handle?" confirmation. Completes with true when
/// the user taps Remove.
Future<bool?> showRemoveChannelDialog(
  BuildContext context, {
  required String handle,
}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: palette.scrim,
    builder: (BuildContext dialogContext) {
      final AppLocalizations l10n = dialogContext.l10n;
      final TextStyle muted = TextStyle(height: 1.5, color: palette.textMuted);
      return Dialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: DefaultTextStyle(
          style: ssV2BaseText(palette),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: ssV2Gap(<Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.errorBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SsV2Icon(
                      SsV2IconGlyph.trash,
                      size: 22,
                      color: palette.errorText,
                    ),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.v2RemoveChannelTitle(handle),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.v2RemoveChannelBody,
                      style: muted.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.v2RemoveChannelNote,
                      style: muted.copyWith(fontSize: 14),
                    ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.link,
                        fixedSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: SsTypography.uiFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.v2Cancel),
                    ),
                    FilledButton(
                      key: const ValueKey<String>('channel-remove-confirm'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.error,
                        foregroundColor: Colors.white,
                        fixedSize: const Size.fromHeight(52),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontFamily: SsTypography.uiFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.v2Remove),
                    ),
                  ],
                ),
              ], 16),
            ),
          ),
        ),
      );
    },
  );
}
