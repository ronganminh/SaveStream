import 'package:flutter/material.dart';

import '../theme/ss_theme.dart';

class SsEmptyState extends StatelessWidget {
  const SsEmptyState({super.key, required this.icon, required this.title, required this.body, this.primary, this.secondary});
  final IconData icon;
  final String title, body;
  final Widget? primary, secondary;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SsSpace.xxl, vertical: SsSpace.xxxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(icon, color: cs.primary, size: 30),
        ),
        const SizedBox(height: SsSpace.lg),
        Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: SsSpace.xs),
        Text(body, style: context.tt.bodyMedium!.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        if (primary != null) ...[const SizedBox(height: SsSpace.xl), primary!],
        if (secondary != null) ...[const SizedBox(height: SsSpace.sm), secondary!],
      ]),
    );
  }
}
