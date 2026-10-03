import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../theme/ss_theme.dart';
import 'ss_button.dart';

enum SsQuotaVariant { free, freeLimit, pro }

class SsQuotaCard extends StatelessWidget {
  const SsQuotaCard({super.key, required this.usage, this.onWatchAd, this.onUpgrade});
  final UsageSnapshot usage;
  final VoidCallback? onWatchAd, onUpgrade;

  SsQuotaVariant get variant => usage.plan.name == 'pro'
      ? SsQuotaVariant.pro
      : (usage.freeExhausted ? SsQuotaVariant.freeLimit : SsQuotaVariant.free);

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    final v = variant;
    final isPro = v == SsQuotaVariant.pro;
    final used = isPro ? usage.cloudHoursUsed : (usage.freeMinutesPool - usage.freeMinutesLeft).toDouble();
    final limit = isPro ? usage.cloudHoursLimit : usage.freeMinutesPool.toDouble();
    final frac = limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final barColor = v == SsQuotaVariant.freeLimit ? ss.recording : (isPro ? ss.cloud : ss.local);

    return Container(
      padding: const EdgeInsets.all(SsSpace.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(SsRadius.card),
        border: Border.all(color: v == SsQuotaVariant.freeLimit ? ss.recording : cs.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isPro ? Icons.cloud_rounded : Icons.smartphone_rounded, size: 20, color: barColor),
          const SizedBox(width: SsSpace.sm),
          Expanded(
            child: Text(isPro ? 'Cloud hours kỳ này' : 'Phút record Local hôm nay',
                style: context.tt.labelMedium!.copyWith(color: cs.onSurfaceVariant)),
          ),
          if (usage.resetAt != null)
            Text('Reset ${fmtTime(usage.resetAt!)}', style: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: SsSpace.sm),
        Text(
          isPro
              ? '${fmtHours(usage.cloudHoursUsed)} / ${fmtHours(usage.cloudHoursLimit)} h'
              : (v == SsQuotaVariant.freeLimit ? 'Hết phút Free hôm nay' : 'Còn ${usage.freeMinutesLeft} phút'),
          style: context.tt.titleLarge,
        ),
        const SizedBox(height: SsSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(SsRadius.pill),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            color: barColor,
            backgroundColor: cs.surfaceContainerHighest,
            semanticsLabel: 'Đã dùng',
            semanticsValue: '${(frac * 100).round()}%',
          ),
        ),
        if (!isPro) ...[
          const SizedBox(height: SsSpace.lg),
          Row(children: [
            if (onWatchAd != null)
              Expanded(
                child: SsButton(
                  label: '+10 phút',
                  icon: Icons.smart_display_rounded,
                  variant: SsButtonVariant.secondary,
                  size: SsButtonSize.md44,
                  onPressed: usage.adsUsed < usage.adsCap ? onWatchAd : null,
                ),
              ),
            if (onWatchAd != null && onUpgrade != null) const SizedBox(width: SsSpace.sm),
            if (onUpgrade != null)
              Expanded(
                child: SsButton(label: 'Nâng cấp Pro', variant: SsButtonVariant.upgrade, size: SsButtonSize.md44, onPressed: onUpgrade),
              ),
          ]),
        ],
      ]),
    );
  }
}
