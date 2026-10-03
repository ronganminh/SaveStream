import 'package:flutter/material.dart';

import '../../../../app/theme/ss_tokens.dart';
import '../../../../core/widgets/savestream_widgets.dart';

class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    required this.title,
    required this.body,
    required this.icon,
    required this.primaryLabel,
    required this.onPrimary,
    this.stepLabel,
    this.child,
    this.secondaryLabel,
    this.onSecondary,
    this.skipLabel,
    this.onSkip,
    this.primaryLoading = false,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final String? stepLabel;
  final Widget? child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final bool primaryLoading;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: <Widget>[
          if (skipLabel != null)
            TextButton(onPressed: onSkip, child: Text(skipLabel!)),
          const SizedBox(width: SsSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                SsSpacing.xl,
                SsSpacing.md,
                SsSpacing.xl,
                SsSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 520,
                    minHeight: constraints.maxHeight - SsSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (stepLabel != null) ...<Widget>[
                        Text(
                          stepLabel!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: SsSpacing.md),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(SsSpacing.lg),
                            child: Icon(
                              icon,
                              size: 32,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: SsSpacing.xl),
                      Text(title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: SsSpacing.sm),
                      Text(
                        body,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (child != null) ...<Widget>[
                        const SizedBox(height: SsSpacing.xl),
                        child!,
                      ],
                      const SizedBox(height: SsSpacing.xxl),
                      SsPrimaryButton(
                        label: primaryLabel,
                        isLoading: primaryLoading,
                        onPressed: onPrimary,
                      ),
                      if (secondaryLabel != null) ...<Widget>[
                        const SizedBox(height: SsSpacing.sm),
                        SsSecondaryButton(
                          label: secondaryLabel!,
                          onPressed: onSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
