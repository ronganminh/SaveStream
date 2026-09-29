import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const SsLogoMark(size: 32),
            const SizedBox(width: SsSpacing.md),
            Text(l10n.appTitle),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            Text(
              l10n.homeFoundationTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: SsSpacing.sm),
            Text(
              l10n.homeFoundationBody,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: SsSpacing.xl),
            SsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.mockFoundationTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  Text(l10n.mockFoundationBody),
                  const SizedBox(height: SsSpacing.lg),
                  Wrap(
                    spacing: SsSpacing.md,
                    runSpacing: SsSpacing.md,
                    children: <Widget>[
                      SsSecondaryButton(
                        label: l10n.creditsTitle,
                        onPressed: () => context.push(AppRoutes.credits),
                      ),
                      SsSecondaryButton(
                        label: l10n.billingTitle,
                        onPressed: () => context.push(AppRoutes.billing),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
