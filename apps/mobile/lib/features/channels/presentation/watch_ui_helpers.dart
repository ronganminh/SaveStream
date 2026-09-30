import 'package:flutter/material.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';

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

String watchStatusReason(AppLocalizations l10n, WatchStatus status) {
  return switch (status) {
    WatchStatus.active => l10n.watchReasonActive,
    WatchStatus.paused => l10n.watchReasonPaused,
    WatchStatus.pausedInsufficientCredit =>
      l10n.watchReasonInsufficientCredit,
    WatchStatus.pausedError => l10n.watchReasonError,
    WatchStatus.disabled => l10n.watchReasonDisabled,
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

String watchTimestamp(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.neverLabel;
  }
  final MaterialLocalizations material = MaterialLocalizations.of(context);
  final DateTime local = value.toLocal();
  return material.formatMediumDate(local) +
      ' · ' +
      material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
}
