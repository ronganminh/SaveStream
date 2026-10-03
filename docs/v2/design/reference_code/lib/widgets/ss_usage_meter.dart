import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsMeterTone { local, cloud, warning }

class SsUsageMeter extends StatelessWidget {
  const SsUsageMeter({super.key, required this.label, required this.used, required this.limit, required this.unit, this.caption, this.tone = SsMeterTone.cloud});
  final String label, unit;
  final String? caption;
  final double used, limit;
  final SsMeterTone tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    final c = switch (tone) { SsMeterTone.local => ss.local, SsMeterTone.cloud => ss.cloud, SsMeterTone.warning => ss.warning };
    String n(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1).replaceAll('.', ',');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(label, style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant))),
        Text('${n(used)} / ${n(limit)} $unit', style: context.ssType.mono.copyWith(color: cs.onSurface)),
      ]),
      const SizedBox(height: SsSpace.sm),
      ClipRRect(
        borderRadius: BorderRadius.circular(SsRadius.pill),
        child: LinearProgressIndicator(
          value: limit == 0 ? 0 : (used / limit).clamp(0, 1),
          minHeight: 6,
          color: c,
          backgroundColor: cs.surfaceContainerHighest,
        ),
      ),
      if (caption != null) ...[
        const SizedBox(height: SsSpace.xs),
        Text(caption!, style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
      ],
    ]);
  }
}
