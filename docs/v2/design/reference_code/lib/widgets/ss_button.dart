import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

enum SsButtonVariant { primary, secondary, tertiary, destructive, upgrade }

enum SsButtonSize { md44, lg52 }

class SsButton extends StatelessWidget {
  const SsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = SsButtonVariant.primary,
    this.size = SsButtonSize.lg52,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final SsButtonVariant variant;
  final SsButtonSize size;
  final bool loading, expand;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs, ss = context.ss;
    final enabled = onPressed != null && !loading;
    Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (variant) {
      case SsButtonVariant.primary:
      case SsButtonVariant.upgrade:
        bg = cs.primary;
        fg = cs.onPrimary;
      case SsButtonVariant.secondary:
        bg = cs.surface;
        fg = cs.onSurface;
        side = BorderSide(color: cs.outline);
      case SsButtonVariant.tertiary:
        bg = Colors.transparent;
        fg = cs.primary;
      case SsButtonVariant.destructive:
        bg = ss.recording;
        fg = cs.onError;
    }
    if (!enabled && !loading) {
      if (variant == SsButtonVariant.tertiary || variant == SsButtonVariant.secondary) {
        fg = ss.disabled;
      } else {
        bg = ss.disabled;
        fg = cs.surface;
      }
    }
    final ic = icon ?? (variant == SsButtonVariant.upgrade ? Icons.workspace_premium_rounded : null);
    final minH = size == SsButtonSize.lg52 ? SsSpace.ctaHeight : SsSpace.minTap;
    final style = (size == SsButtonSize.lg52 ? context.tt.labelLarge : context.tt.labelMedium)!.copyWith(color: fg);

    final content = loading
        ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ic != null) ...[Icon(ic, size: 20, color: fg), const SizedBox(width: SsSpace.sm)],
              Flexible(child: Text(label, style: style, textAlign: TextAlign.center)),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SsRadius.cta), side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH, minWidth: expand ? double.infinity : 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SsSpace.lg, vertical: SsSpace.sm),
              child: Center(widthFactor: expand ? null : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
