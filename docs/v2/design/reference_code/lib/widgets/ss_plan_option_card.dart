import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

class SsPlanOptionCard extends StatelessWidget {
  const SsPlanOptionCard({super.key, required this.title, required this.price, this.subtitle, this.badge, required this.selected, required this.onTap});
  final String title, price;
  final String? subtitle, badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SsRadius.card),
          side: BorderSide(color: selected ? cs.primary : cs.outline, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(SsRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SsSpace.lg),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: SsSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: SsSpace.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(title, style: context.tt.titleSmall),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: ss.successSubtle, borderRadius: BorderRadius.circular(SsRadius.pill)),
                        child: Text(badge!, style: context.tt.labelSmall!.copyWith(color: ss.success, fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              Text(price, style: context.ssType.mono.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ]),
          ),
        ),
      ),
    );
  }
}
