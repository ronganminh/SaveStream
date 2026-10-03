import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsRowTrailing { chevron, external, toggle, radio, check, none }

class SsSettingsGroup extends StatelessWidget {
  const SsSettingsGroup({super.key, this.header, required this.children});
  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(SsSpace.xs, SsSpace.xxl, SsSpace.xs, SsSpace.sm),
          child: Text(header!.toUpperCase(),
              style: context.tt.labelSmall!.copyWith(color: cs.onSurfaceVariant, letterSpacing: .8, fontWeight: FontWeight.w600)),
        ),
      Container(
        decoration: BoxDecoration(
            color: cs.surface, borderRadius: BorderRadius.circular(SsRadius.card), border: Border.all(color: cs.outline)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(indent: 52, color: cs.outline),
            children[i],
          ],
        ]),
      ),
    ]);
  }
}

class SsSettingsRow extends StatelessWidget {
  const SsSettingsRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing = SsRowTrailing.chevron,
    this.toggled = false,
    this.destructive = false,
    this.onTap,
    this.onToggle,
  });
  final IconData? leading;
  final String title;
  final String? subtitle, value;
  final SsRowTrailing trailing;
  final bool toggled, destructive;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = destructive ? context.ss.recording : cs.onSurface;
    final t = switch (trailing) {
      SsRowTrailing.chevron => Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      SsRowTrailing.external => Icon(Icons.open_in_new_rounded, size: 20, color: cs.onSurfaceVariant),
      SsRowTrailing.toggle => Switch(value: toggled, onChanged: onToggle),
      SsRowTrailing.radio => Icon(toggled ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          color: toggled ? cs.primary : cs.onSurfaceVariant),
      SsRowTrailing.check => toggled ? Icon(Icons.check_rounded, color: cs.primary) : const SizedBox(width: 24),
      SsRowTrailing.none => const SizedBox.shrink(),
    };
    return MergeSemantics(
      child: InkWell(
        onTap: trailing == SsRowTrailing.toggle ? () => onToggle?.call(!toggled) : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SsSpace.rowHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SsSpace.lg, vertical: SsSpace.sm),
            child: Row(children: [
              if (leading != null) ...[Icon(leading, size: 22, color: destructive ? fg : cs.onSurfaceVariant), const SizedBox(width: 14)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.tt.bodyLarge!.copyWith(color: fg)),
                  if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall!.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              if (value != null) ...[
                const SizedBox(width: SsSpace.sm),
                Flexible(child: Text(value!, style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.end)),
              ],
              const SizedBox(width: SsSpace.xs),
              t,
            ]),
          ),
        ),
      ),
    );
  }
}
