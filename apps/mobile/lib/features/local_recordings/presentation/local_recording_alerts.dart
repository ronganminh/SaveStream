import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/local_recorder.dart';
import 'controllers/rewarded_minutes_controller.dart';

class LocalRecordingAlerts extends StatefulWidget {
  const LocalRecordingAlerts({
    required this.state,
    required this.creatorName,
    required this.remainingSeconds,
    required this.isUnlimited,
    required this.minutesPerReward,
    required this.extensionsCap,
    required this.rewardState,
    this.onRewardRequested,
    this.onMinuteWarningEntered,
    super.key,
  });

  final LocalRecorderState state;
  final String creatorName;
  final int remainingSeconds;
  final bool isUnlimited;
  final int minutesPerReward;
  final int extensionsCap;
  final RewardedMinutesState rewardState;
  final VoidCallback? onRewardRequested;
  final VoidCallback? onMinuteWarningEntered;

  @override
  State<LocalRecordingAlerts> createState() => _LocalRecordingAlertsState();
}

class _LocalRecordingAlertsState extends State<LocalRecordingAlerts> {
  Timer? _slowStartingTimer;
  bool _slowStarting = false;
  bool _minuteWarningAnnounced = false;

  @override
  void initState() {
    super.initState();
    _syncStartingTimer();
    _syncMinuteWarning();
  }

  @override
  void didUpdateWidget(LocalRecordingAlerts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.phase != widget.state.phase) {
      _syncStartingTimer();
    }
    _syncMinuteWarning();
  }

  @override
  void dispose() {
    _slowStartingTimer?.cancel();
    super.dispose();
  }

  void _syncStartingTimer() {
    _slowStartingTimer?.cancel();
    if (widget.state.phase != LocalRecorderPhase.starting) {
      _slowStarting = false;
      return;
    }

    _slowStarting = false;
    _slowStartingTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted || widget.state.phase != LocalRecorderPhase.starting) {
        return;
      }
      setState(() => _slowStarting = true);
    });
  }

  void _syncMinuteWarning() {
    final bool warning = _showMinuteWarning;
    if (!warning) {
      _minuteWarningAnnounced = false;
      return;
    }
    if (_minuteWarningAnnounced) return;

    _minuteWarningAnnounced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final VoidCallback? callback = widget.onMinuteWarningEntered;
      if (callback != null) {
        callback();
      } else {
        unawaited(HapticFeedback.lightImpact());
      }
    });
  }

  bool get _showMinuteWarning {
    return !widget.isUnlimited &&
        widget.state.phase == LocalRecorderPhase.recording &&
        widget.remainingSeconds > 0 &&
        widget.remainingSeconds <= 60;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildPhaseAlert(context),
        if (_buildRewardAlert(context)
            case final Widget rewardAlert) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          rewardAlert,
        ],
        if (_showMinuteWarning) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: context.l10n.localRecordingMinuteWarningTitle,
            message: context.l10n.localRecordingMinuteWarningBody,
            tone: SsInlineAlertTone.warning,
          ),
          if (widget.onRewardRequested != null && _canRequestReward)
            Align(
              alignment: Alignment.centerLeft,
              child: SsTextAction(
                label: context.l10n.localRecordingRewardMinutesAction(
                  widget.minutesPerReward,
                ),
                icon: Icons.more_time_rounded,
                onPressed: widget.onRewardRequested,
              ),
            ),
        ],
      ],
    );
  }

  bool get _canRequestReward {
    return switch (widget.rewardState.phase) {
      RewardedMinutesPhase.idle ||
      RewardedMinutesPhase.success ||
      RewardedMinutesPhase.noFill ||
      RewardedMinutesPhase.invalid ||
      RewardedMinutesPhase.error => true,
      RewardedMinutesPhase.loadingAd ||
      RewardedMinutesPhase.verifying ||
      RewardedMinutesPhase.pending ||
      RewardedMinutesPhase.locked ||
      RewardedMinutesPhase.maxExtensions ||
      RewardedMinutesPhase.dailyCap => false,
    };
  }

  Widget? _buildRewardAlert(BuildContext context) {
    return switch (widget.rewardState.phase) {
      RewardedMinutesPhase.pending => SsInlineAlert(
        title: context.l10n.rewardMinutesPendingTitle,
        message: context.l10n.rewardMinutesPendingBody,
      ),
      RewardedMinutesPhase.success => SsInlineAlert(
        title: context.l10n.rewardMinutesSuccessTitle(widget.minutesPerReward),
        message: context.l10n.rewardMinutesSuccessBody(
          widget.rewardState.extensionCount,
          widget.extensionsCap,
        ),
        tone: SsInlineAlertTone.success,
      ),
      RewardedMinutesPhase.invalid => SsInlineAlert(
        title: context.l10n.rewardMinutesInvalidTitle,
        message: context.l10n.rewardMinutesInvalidBody,
        tone: SsInlineAlertTone.error,
      ),
      RewardedMinutesPhase.locked => SsInlineAlert(
        title: context.l10n.rewardMinutesLockedTitle,
        message: context.l10n.rewardMinutesLockedBody,
        tone: SsInlineAlertTone.warning,
      ),
      RewardedMinutesPhase.idle ||
      RewardedMinutesPhase.loadingAd ||
      RewardedMinutesPhase.verifying ||
      RewardedMinutesPhase.noFill ||
      RewardedMinutesPhase.maxExtensions ||
      RewardedMinutesPhase.dailyCap ||
      RewardedMinutesPhase.error => null,
    };
  }

  Widget _buildPhaseAlert(BuildContext context) {
    return switch (widget.state.phase) {
      LocalRecorderPhase.starting => SsInlineAlert(
        title: context.l10n.recordingStatusStarting,
        message: _slowStarting
            ? context.l10n.localRecordingConnectingSlowBody
            : context.l10n.localRecordingConnectingBody(widget.creatorName),
      ),
      LocalRecorderPhase.reconnecting => SsInlineAlert(
        title: context.l10n.recordingStatusReconnecting,
        message: context.l10n.recordingReconnectingBody,
        tone: SsInlineAlertTone.warning,
      ),
      LocalRecorderPhase.finalizing => SsInlineAlert(
        title: context.l10n.recordingStatusFinalizing,
        message: context.l10n.recordingFinalizingBody,
      ),
      LocalRecorderPhase.error => SsInlineAlert(
        title: context.l10n.localRecordingErrorTitle,
        message: widget.state.errorMessage,
        tone: SsInlineAlertTone.error,
      ),
      LocalRecorderPhase.idle ||
      LocalRecorderPhase.recording ||
      LocalRecorderPhase.stopped => SsInlineAlert(
        title: context.l10n.localRecordingStatusActive,
        message: context.l10n.localRecordingSavedHere(
          formatFileSize(widget.state.sizeBytes),
        ),
        tone: SsInlineAlertTone.success,
      ),
    };
  }
}
