import 'package:flutter/material.dart';

import '../../app/theme/ss_tokens.dart';
import 'ss_buttons.dart';

class SsEmptyState extends StatelessWidget {
  const SsEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(icon: icon, title: title, message: message);
  }
}

class SsErrorState extends StatelessWidget {
  const SsErrorState({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: Icons.error_outline_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message,
      action: SsSecondaryButton(label: retryLabel, onPressed: onRetry),
    );
  }
}

class SsLoadingView extends StatelessWidget {
  const SsLoadingView({this.label, super.key});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SsSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          if (label != null) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class SsSkeleton extends StatelessWidget {
  const SsSkeleton({
    this.width = double.infinity,
    this.height = 16,
    this.radius = SsRadii.sm,
    super.key,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(SsSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 36, color: iconColor ?? colors.onSurfaceVariant),
          const SizedBox(height: SsSpacing.md),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SsSpacing.sm),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: SsSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
