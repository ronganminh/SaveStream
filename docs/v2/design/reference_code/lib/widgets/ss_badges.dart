import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../theme/ss_theme.dart';

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, this.icon, this.dot = false, this.border});
  final String label;
  final Color bg, fg;
  final IconData? icon;
  final bool dot;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SsRadius.pill),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(label, style: context.tt.labelSmall!.copyWith(color: fg, fontWeight: FontWeight.w700, letterSpacing: .6)),
      ]),
    );
  }
}

class SsLiveBadge extends StatelessWidget {
  const SsLiveBadge({super.key, required this.status});
  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    return switch (status) {
      LiveStatus.live => _Pill(label: 'LIVE', bg: ss.recording, fg: cs.onError, dot: true),
      LiveStatus.offline => _Pill(label: 'OFFLINE', bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant),
      LiveStatus.checking => _Pill(label: 'CHECKING', bg: ss.infoSubtle, fg: ss.info, icon: Icons.sync_rounded),
      LiveStatus.unknown =>
        _Pill(label: 'UNKNOWN', bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant, icon: Icons.help_rounded),
      LiveStatus.paused =>
        _Pill(label: 'PAUSED', bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant, icon: Icons.pause_rounded),
    };
  }
}

/// Local/Cloud luôn đi kèm icon + chữ.
class SsLocationChip extends StatelessWidget {
  const SsLocationChip({super.key, required this.engine, this.label});
  final Engine engine;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ss = context.ss;
    final local = engine == Engine.local;
    return _Pill(
      label: label ?? engine.label,
      bg: local ? ss.localSubtle : ss.cloudSubtle,
      fg: local ? ss.local : ss.cloud,
      icon: local ? Icons.smartphone_rounded : Icons.cloud_rounded,
    );
  }
}

class SsPlanBadge extends StatelessWidget {
  const SsPlanBadge({super.key, required this.plan});
  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return plan == Plan.pro
        ? _Pill(label: 'PRO', bg: cs.primaryContainer, fg: cs.primary, icon: Icons.workspace_premium_rounded)
        : _Pill(label: 'FREE', bg: cs.surfaceContainerHighest, fg: cs.onSurfaceVariant, border: cs.outline);
  }
}

class SsStatusPill extends StatelessWidget {
  const SsStatusPill({super.key, required this.status});
  final RecordingStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    final (String l, Color bg, Color fg) = switch (status) {
      RecordingStatus.starting => ('STARTING', ss.infoSubtle, ss.info),
      RecordingStatus.waitingForCloudSlot => ('WAITING', ss.warningSubtle, ss.onWarningSubtle),
      RecordingStatus.recording => ('REC', ss.recordingSubtle, ss.recording),
      RecordingStatus.reconnecting => ('RECONNECTING', ss.warningSubtle, ss.onWarningSubtle),
      RecordingStatus.finalizing => ('FINALIZING', ss.infoSubtle, ss.info),
      RecordingStatus.processing => ('PROCESSING', ss.infoSubtle, ss.info),
      RecordingStatus.completed => ('COMPLETED', ss.successSubtle, ss.success),
      RecordingStatus.partial => ('PARTIAL', ss.warningSubtle, ss.onWarningSubtle),
      RecordingStatus.recovered => ('RECOVERED', ss.warningSubtle, ss.onWarningSubtle),
      RecordingStatus.failed => ('FAILED', ss.recordingSubtle, ss.recording),
      RecordingStatus.missedNoCloudSlot => ('MISSED', ss.recordingSubtle, ss.recording),
      RecordingStatus.expired => ('EXPIRED', cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    return _Pill(label: l, bg: bg, fg: fg, dot: status == RecordingStatus.recording);
  }
}
