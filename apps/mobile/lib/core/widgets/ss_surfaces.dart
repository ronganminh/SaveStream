import 'package:flutter/material.dart';

import '../../app/theme/ss_semantic_colors.dart';
import '../../app/theme/ss_tokens.dart';

class SsCard extends StatelessWidget {
  const SsCard({
    required this.child,
    this.padding = const EdgeInsets.all(SsSpacing.lg),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: SsRadii.card,
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

enum SsStatusTone { neutral, success, warning, error, recording }

class SsStatusChip extends StatelessWidget {
  const SsStatusChip({
    required this.label,
    this.tone = SsStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final SsStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final SsSemanticColors semantic = context.semanticColors;
    final Color foreground = switch (tone) {
      SsStatusTone.neutral => colors.onSurfaceVariant,
      SsStatusTone.success => semantic.success,
      SsStatusTone.warning => semantic.warning,
      SsStatusTone.error => semantic.error,
      SsStatusTone.recording => semantic.recording,
    };

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.10),
          borderRadius: const BorderRadius.all(Radius.circular(SsRadii.pill)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SsSpacing.md,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: SsSpacing.xs),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SsAvatar extends StatelessWidget {
  const SsAvatar({required this.label, this.radius = 20, super.key});

  final String label;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final String initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .map((String part) => part.substring(0, 1).toUpperCase())
        .join();

    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        child: Text(initials.isEmpty ? 'S' : initials),
      ),
    );
  }
}

class SsListTile extends StatelessWidget {
  const SsListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget tile = MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: leading,
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );

    if (onTap == null) {
      return tile;
    }
    return Semantics(button: true, child: tile);
  }
}

class SsSectionHeader extends StatelessWidget {
  const SsSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ),
          ),
      ],
    );
  }
}
