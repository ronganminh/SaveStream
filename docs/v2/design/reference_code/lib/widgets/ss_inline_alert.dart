import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsAlertTone { info, success, warning, error, upgrade, cloud }

({Color bg, Color fg, Color text, IconData icon}) ssToneColors(BuildContext c, SsAlertTone t) {
  final cs = c.cs, ss = c.ss;
  return switch (t) {
    SsAlertTone.info => (bg: ss.infoSubtle, fg: ss.info, text: cs.onSurface, icon: Icons.info_rounded),
    SsAlertTone.success => (bg: ss.successSubtle, fg: ss.success, text: cs.onSurface, icon: Icons.check_circle_rounded),
    SsAlertTone.warning =>
      (bg: ss.warningSubtle, fg: ss.warning, text: ss.onWarningSubtle, icon: Icons.warning_rounded),
    SsAlertTone.error => (bg: ss.recordingSubtle, fg: ss.recording, text: cs.onSurface, icon: Icons.error_rounded),
    SsAlertTone.upgrade =>
      (bg: cs.primaryContainer, fg: cs.primary, text: cs.onSurface, icon: Icons.workspace_premium_rounded),
    SsAlertTone.cloud => (bg: ss.cloudSubtle, fg: ss.cloud, text: cs.onSurface, icon: Icons.cloud_rounded),
  };
}

class SsInlineAlert extends StatelessWidget {
  const SsInlineAlert({super.key, required this.title, this.body, this.tone = SsAlertTone.info, this.icon, this.actions = const []});
  final String title;
  final String? body;
  final SsAlertTone tone;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = ssToneColors(context, tone);
    return Semantics(
      container: true,
      liveRegion: tone == SsAlertTone.error || tone == SsAlertTone.warning,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: SsSpace.lg, vertical: 14),
        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(SsRadius.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon ?? t.icon, color: t.fg, size: 22),
          const SizedBox(width: SsSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleSmall!.copyWith(color: t.text, fontSize: 15)),
              if (body != null) ...[
                const SizedBox(height: 2),
                Text(body!, style: context.tt.bodyMedium!.copyWith(color: tone == SsAlertTone.warning ? t.text : context.cs.onSurfaceVariant)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: SsSpace.sm),
                Wrap(spacing: SsSpace.sm, runSpacing: SsSpace.sm, children: actions),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
