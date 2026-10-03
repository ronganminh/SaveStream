import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

class SsFilterChipItem {
  const SsFilterChipItem(this.label, {this.count, this.icon});
  final String label;
  final int? count;
  final IconData? icon;
}

class SsFilterChips extends StatelessWidget {
  const SsFilterChips({super.key, required this.items, required this.selected, required this.onSelected});
  final List<SsFilterChipItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SsSpace.screenH),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: SsSpace.sm),
            _chip(context, cs, items[i], i == selected, () => onSelected(i)),
          ],
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, ColorScheme cs, SsFilterChipItem it, bool on, VoidCallback tap) {
    final fg = on ? cs.primary : cs.onSurface;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? cs.primaryContainer : cs.surface,
        shape: StadiumBorder(side: BorderSide(color: on ? cs.primary : cs.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: tap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (it.icon != null) ...[Icon(it.icon, size: 16, color: fg), const SizedBox(width: 6)],
                Text(it.label, style: context.tt.labelMedium!.copyWith(color: fg)),
                if (it.count != null) ...[
                  const SizedBox(width: 6),
                  Text('${it.count}', style: context.ssType.mono.copyWith(color: on ? cs.primary : cs.onSurfaceVariant)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
