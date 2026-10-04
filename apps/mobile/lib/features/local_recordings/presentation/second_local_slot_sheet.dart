import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'controllers/second_local_slot_controller.dart';

Future<bool> showSecondLocalSlotSheet({
  required BuildContext context,
  required WidgetRef ref,
  required LocalEntitlement entitlement,
  required String targetCreatorName,
}) async {
  ref
      .read(secondLocalSlotControllerProvider.notifier)
      .syncEntitlement(entitlement);
  final bool? startSecond = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return SecondLocalSlotSheet(
        entitlement: entitlement,
        targetCreatorName: targetCreatorName,
      );
    },
  );
  return startSecond ?? false;
}

class SecondLocalSlotSheet extends ConsumerWidget {
  const SecondLocalSlotSheet({
    required this.entitlement,
    required this.targetCreatorName,
    super.key,
  });

  final LocalEntitlement entitlement;
  final String targetCreatorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SecondLocalSlotState state = ref.watch(
      secondLocalSlotControllerProvider,
    );
    final SecondLocalSlotPhase phase = _effectivePhase(state);
    final DateTime? expiresAt =
        state.expiresAt ?? entitlement.secondSlotExpiresAt;

    return SsBottomSheet(
      title: _title(context, phase),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _body(context, phase, state, expiresAt),
          const SizedBox(height: SsSpacing.lg),
          _actions(context, ref, phase, state),
        ],
      ),
    );
  }

  SecondLocalSlotPhase _effectivePhase(SecondLocalSlotState state) {
    final DateTime? expiresAt =
        state.expiresAt ?? entitlement.secondSlotExpiresAt;
    if (entitlement.maxConcurrentSessions >= 2 &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now())) {
      return SecondLocalSlotPhase.unlocked;
    }
    if (expiresAt != null &&
        !expiresAt.isAfter(DateTime.now()) &&
        state.phase == SecondLocalSlotPhase.idle) {
      return SecondLocalSlotPhase.expired;
    }
    return state.phase;
  }

  String _title(BuildContext context, SecondLocalSlotPhase phase) {
    return switch (phase) {
      SecondLocalSlotPhase.unlocked =>
        context.l10n.secondLocalSlotUnlockedTitle,
      SecondLocalSlotPhase.expired =>
        context.l10n.secondLocalSlotExpiredTitle,
      SecondLocalSlotPhase.locked =>
        context.l10n.rewardMinutesLockedTitle,
      SecondLocalSlotPhase.dailyCap =>
        context.l10n.rewardMinutesDailyCapTitle,
      _ => context.l10n.secondLocalSlotTitle,
    };
  }

  Widget _body(
    BuildContext context,
    SecondLocalSlotPhase phase,
    SecondLocalSlotState state,
    DateTime? expiresAt,
  ) {
    final int dailyUsed = entitlement.rewardsUsedToday + state.verifiedRewards;
    final int dailyVisible = dailyUsed > entitlement.rewardsCapPerDay
        ? entitlement.rewardsCapPerDay
        : dailyUsed;

    return switch (phase) {
      SecondLocalSlotPhase.idle ||
      SecondLocalSlotPhase.progress => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.secondLocalSlotOfferBody),
          const SizedBox(height: SsSpacing.md),
          Text(
            context.l10n.secondLocalSlotProgress(
              state.verifiedRewards,
              SecondLocalSlotController.rewardsRequired,
            ),
          ),
          Text(
            context.l10n.rewardMinutesDailyProgress(
              dailyVisible,
              entitlement.rewardsCapPerDay,
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: context.l10n.secondLocalSlotSharedQuotaTitle,
            message: context.l10n.secondLocalSlotSharedQuotaBody,
            tone: SsInlineAlertTone.warning,
          ),
        ],
      ),
      SecondLocalSlotPhase.loadingAd => SsInlineAlert(
        title: context.l10n.rewardMinutesLoadingTitle,
        message: context.l10n.rewardMinutesLoadingBody,
      ),
      SecondLocalSlotPhase.verifying => SsChecklist(
        items: <SsChecklistItem>[
          SsChecklistItem(
            label: context.l10n.rewardMinutesAdCompleteStep,
            done: true,
          ),
          SsChecklistItem(label: context.l10n.rewardMinutesVerifyStep),
          SsChecklistItem(
            label: context.l10n.secondLocalSlotVerifyStep(
              state.verifiedRewards + 1,
              SecondLocalSlotController.rewardsRequired,
            ),
          ),
        ],
      ),
      SecondLocalSlotPhase.pending => SsInlineAlert(
        title: context.l10n.rewardMinutesPendingTitle,
        message: context.l10n.secondLocalSlotPendingBody,
      ),
      SecondLocalSlotPhase.unlocked => SsInlineAlert(
        title: context.l10n.secondLocalSlotUnlockedTitle,
        message: context.l10n.secondLocalSlotUnlockedBody(
          _formatTime(context, expiresAt),
        ),
        tone: SsInlineAlertTone.success,
      ),
      SecondLocalSlotPhase.noFill => SsInlineAlert(
        title: context.l10n.rewardMinutesNoFillTitle,
        message: context.l10n.rewardMinutesNoFillBody,
        tone: SsInlineAlertTone.warning,
      ),
      SecondLocalSlotPhase.invalid => SsInlineAlert(
        title: context.l10n.rewardMinutesInvalidTitle,
        message: context.l10n.rewardMinutesInvalidBody,
        tone: SsInlineAlertTone.error,
      ),
      SecondLocalSlotPhase.locked => SsInlineAlert(
        title: context.l10n.rewardMinutesLockedTitle,
        message: context.l10n.rewardMinutesLockedBody,
        tone: SsInlineAlertTone.warning,
      ),
      SecondLocalSlotPhase.dailyCap => SsInlineAlert(
        title: context.l10n.rewardMinutesDailyCapTitle,
        message: context.l10n.rewardMinutesDailyCapBody(
          entitlement.rewardsCapPerDay,
        ),
        tone: SsInlineAlertTone.warning,
      ),
      SecondLocalSlotPhase.expired => SsInlineAlert(
        title: context.l10n.secondLocalSlotExpiredTitle,
        message: context.l10n.secondLocalSlotExpiredBody(
          _formatTime(context, expiresAt),
        ),
        tone: SsInlineAlertTone.warning,
      ),
      SecondLocalSlotPhase.error => SsInlineAlert(
        title: context.l10n.genericErrorTitle,
        message: state.errorMessage,
        tone: SsInlineAlertTone.error,
      ),
    };
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    SecondLocalSlotPhase phase,
    SecondLocalSlotState state,
  ) {
    if (phase == SecondLocalSlotPhase.unlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsPrimaryButton(
            label: context.l10n.secondLocalSlotRecordNow(targetCreatorName),
            icon: Icons.fiber_manual_record_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: SsSpacing.sm),
          SsSecondaryButton(
            label: context.l10n.laterAction,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      );
    }

    final bool canWatch =
        phase == SecondLocalSlotPhase.idle ||
        phase == SecondLocalSlotPhase.progress ||
        phase == SecondLocalSlotPhase.noFill ||
        phase == SecondLocalSlotPhase.invalid ||
        phase == SecondLocalSlotPhase.error ||
        phase == SecondLocalSlotPhase.expired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (canWatch)
          SsPrimaryButton(
            label: context.l10n.secondLocalSlotWatchAdAction(
              state.verifiedRewards + 1,
              SecondLocalSlotController.rewardsRequired,
            ),
            icon: Icons.ondemand_video_rounded,
            onPressed: () {
              ref
                  .read(secondLocalSlotControllerProvider.notifier)
                  .start(entitlement);
            },
          ),
        if (phase == SecondLocalSlotPhase.loadingAd ||
            phase == SecondLocalSlotPhase.verifying)
          SsPrimaryButton(
            label: context.l10n.rewardMinutesWorkingAction,
            isLoading: true,
            onPressed: null,
          ),
        const SizedBox(height: SsSpacing.sm),
        SsSecondaryButton(
          label: context.l10n.laterAction,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime? value) {
    if (value == null) return context.l10n.timeUnknownLabel;
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value.toLocal()),
    );
  }
}
