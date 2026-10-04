import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'controllers/rewarded_minutes_controller.dart';

Future<void> showRewardedMinutesSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LocalEntitlement entitlement,
  required int extensionsUsed,
}) async {
  ref.read(rewardedMinutesControllerProvider.notifier).reset();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (BuildContext sheetContext) {
      return RewardedMinutesSheet(
        entitlement: entitlement,
        extensionsUsed: extensionsUsed,
      );
    },
  );
}

class RewardedMinutesSheet extends ConsumerStatefulWidget {
  const RewardedMinutesSheet({
    required this.entitlement,
    required this.extensionsUsed,
    super.key,
  });

  final LocalEntitlement entitlement;
  final int extensionsUsed;

  @override
  ConsumerState<RewardedMinutesSheet> createState() =>
      _RewardedMinutesSheetState();
}

class _RewardedMinutesSheetState
    extends ConsumerState<RewardedMinutesSheet> {
  Timer? _successTimer;

  @override
  void dispose() {
    _successTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RewardedMinutesState state = ref.watch(
      rewardedMinutesControllerProvider,
    );
    ref.listen<RewardedMinutesState>(
      rewardedMinutesControllerProvider,
      (RewardedMinutesState? previous, RewardedMinutesState next) {
        if (next.phase == RewardedMinutesPhase.pending) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
        if (next.phase == RewardedMinutesPhase.success) {
          _successTimer?.cancel();
          _successTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
    );

    final RewardedMinutesPhase phase = _effectivePhase(state);
    return SsBottomSheet(
      title: _title(context, phase),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _content(context, phase, state),
          const SizedBox(height: SsSpacing.lg),
          _actions(context, phase),
        ],
      ),
    );
  }

  RewardedMinutesPhase _effectivePhase(RewardedMinutesState state) {
    if (state.phase != RewardedMinutesPhase.idle) {
      return state.phase;
    }
    if (widget.extensionsUsed >=
        widget.entitlement.extensionsCapPerRecording) {
      return RewardedMinutesPhase.maxExtensions;
    }
    if (widget.entitlement.rewardsUsedToday >=
        widget.entitlement.rewardsCapPerDay) {
      return RewardedMinutesPhase.dailyCap;
    }
    return RewardedMinutesPhase.idle;
  }

  String _title(BuildContext context, RewardedMinutesPhase phase) {
    return switch (phase) {
      RewardedMinutesPhase.idle => context.l10n.rewardMinutesOfferTitle(
        widget.entitlement.minutesPerReward,
      ),
      RewardedMinutesPhase.loadingAd =>
        context.l10n.rewardMinutesLoadingTitle,
      RewardedMinutesPhase.verifying =>
        context.l10n.rewardMinutesVerifyingTitle,
      RewardedMinutesPhase.pending =>
        context.l10n.rewardMinutesPendingTitle,
      RewardedMinutesPhase.success => context.l10n.rewardMinutesSuccessTitle(
        widget.entitlement.minutesPerReward,
      ),
      RewardedMinutesPhase.noFill =>
        context.l10n.rewardMinutesNoFillTitle,
      RewardedMinutesPhase.invalid =>
        context.l10n.rewardMinutesInvalidTitle,
      RewardedMinutesPhase.maxExtensions =>
        context.l10n.rewardMinutesMaxTitle,
      RewardedMinutesPhase.dailyCap =>
        context.l10n.rewardMinutesDailyCapTitle,
      RewardedMinutesPhase.error => context.l10n.genericErrorTitle,
    };
  }

  Widget _content(
    BuildContext context,
    RewardedMinutesPhase phase,
    RewardedMinutesState state,
  ) {
    final int extensions = phase == RewardedMinutesPhase.success
        ? state.extensionCount
        : widget.extensionsUsed;

    return switch (phase) {
      RewardedMinutesPhase.idle => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.rewardMinutesOfferBody(
              widget.entitlement.minutesPerReward,
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          Text(
            context.l10n.rewardMinutesExtensionProgress(
              extensions,
              widget.entitlement.extensionsCapPerRecording,
            ),
          ),
          Text(
            context.l10n.rewardMinutesDailyProgress(
              widget.entitlement.rewardsUsedToday,
              widget.entitlement.rewardsCapPerDay,
            ),
          ),
        ],
      ),
      RewardedMinutesPhase.loadingAd => SsInlineAlert(
        title: context.l10n.rewardMinutesLoadingTitle,
        message: context.l10n.rewardMinutesLoadingBody,
      ),
      RewardedMinutesPhase.verifying => SsChecklist(
        items: <SsChecklistItem>[
          SsChecklistItem(
            label: context.l10n.rewardMinutesAdCompleteStep,
            done: true,
          ),
          SsChecklistItem(
            label: context.l10n.rewardMinutesVerifyStep,
          ),
          SsChecklistItem(
            label: context.l10n.rewardMinutesGrantStep(
              widget.entitlement.minutesPerReward,
            ),
          ),
        ],
      ),
      RewardedMinutesPhase.pending => SsInlineAlert(
        title: context.l10n.rewardMinutesPendingTitle,
        message: context.l10n.rewardMinutesPendingBody,
      ),
      RewardedMinutesPhase.success => SsInlineAlert(
        title: context.l10n.rewardMinutesSuccessTitle(
          widget.entitlement.minutesPerReward,
        ),
        message: context.l10n.rewardMinutesSuccessBody(
          extensions,
          widget.entitlement.extensionsCapPerRecording,
        ),
        tone: SsInlineAlertTone.success,
      ),
      RewardedMinutesPhase.noFill => SsInlineAlert(
        title: context.l10n.rewardMinutesNoFillTitle,
        message: context.l10n.rewardMinutesNoFillBody,
        tone: SsInlineAlertTone.warning,
      ),
      RewardedMinutesPhase.invalid => SsInlineAlert(
        title: context.l10n.rewardMinutesInvalidTitle,
        message: context.l10n.rewardMinutesInvalidBody,
        tone: SsInlineAlertTone.error,
      ),
      RewardedMinutesPhase.maxExtensions => SsInlineAlert(
        title: context.l10n.rewardMinutesMaxTitle,
        message: context.l10n.rewardMinutesMaxBody(
          widget.entitlement.extensionsCapPerRecording,
        ),
        tone: SsInlineAlertTone.warning,
      ),
      RewardedMinutesPhase.dailyCap => SsInlineAlert(
        title: context.l10n.rewardMinutesDailyCapTitle,
        message: context.l10n.rewardMinutesDailyCapBody(
          widget.entitlement.rewardsCapPerDay,
        ),
        tone: SsInlineAlertTone.warning,
      ),
      RewardedMinutesPhase.error => SsInlineAlert(
        title: context.l10n.genericErrorTitle,
        message: state.errorMessage,
        tone: SsInlineAlertTone.error,
      ),
    };
  }

  Widget _actions(BuildContext context, RewardedMinutesPhase phase) {
    final bool canStart =
        phase == RewardedMinutesPhase.idle ||
        phase == RewardedMinutesPhase.noFill ||
        phase == RewardedMinutesPhase.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (canStart)
          SsPrimaryButton(
            label: phase == RewardedMinutesPhase.idle
                ? context.l10n.rewardMinutesWatchAdAction
                : context.l10n.retryAction,
            icon: Icons.ondemand_video_rounded,
            onPressed: () {
              ref.read(rewardedMinutesControllerProvider.notifier).start(
                    entitlement: widget.entitlement,
                    extensionsUsed: widget.extensionsUsed,
                  );
            },
          ),
        if (phase == RewardedMinutesPhase.loadingAd ||
            phase == RewardedMinutesPhase.verifying)
          SsPrimaryButton(
            label: context.l10n.rewardMinutesWorkingAction,
            isLoading: true,
            onPressed: null,
          ),
        if (phase != RewardedMinutesPhase.success) ...<Widget>[
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: context.l10n.closeAction,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}
