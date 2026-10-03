import 'package:flutter/material.dart';

import '../../app/theme/ss_tokens.dart';

/// Tab-level header from the V2 design: a bold title with an optional
/// subtitle and trailing actions. It is a plain widget instead of an AppBar so
/// its height grows with large text scales.
class SsLargeHeader extends StatelessWidget {
  const SsLargeHeader({
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SsSpacing.lg,
        SsSpacing.sm,
        SsSpacing.sm,
        SsSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
