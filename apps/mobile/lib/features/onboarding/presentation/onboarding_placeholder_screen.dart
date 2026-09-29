import 'package:flutter/material.dart';

import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class OnboardingPlaceholderScreen extends StatelessWidget {
  const OnboardingPlaceholderScreen({required this.session, super.key});

  final AppSessionController session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SsLogoMark(size: 72),
                  const SizedBox(height: SsSpacing.xl),
                  Text(
                    l10n.onboardingPreviewTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Text(
                    l10n.onboardingPreviewBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  SsPrimaryButton(
                    label: l10n.continueAction,
                    onPressed: session.completeOnboarding,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
