import 'package:flutter/material.dart';

import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.session, super.key});

  final AppSessionController session;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _confirmedPermission = false;

  void _next() {
    if (_step < 2) {
      setState(() {
        _step += 1;
      });
      return;
    }
    if (_confirmedPermission) {
      widget.session.completeOnboarding();
    }
  }

  void _back() {
    if (_step == 0) {
      return;
    }
    setState(() {
      _step -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<_OnboardingStep> steps = <_OnboardingStep>[
      _OnboardingStep(
        icon: Icons.auto_awesome_rounded,
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
      ),
      _OnboardingStep(
        icon: Icons.cloud_done_outlined,
        title: l10n.onboardingCloudTitle,
        body: l10n.onboardingCloudBody,
      ),
      _OnboardingStep(
        icon: Icons.verified_user_outlined,
        title: l10n.onboardingConsentTitle,
        body: l10n.onboardingConsentBody,
      ),
    ];
    final _OnboardingStep current = steps[_step];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SsSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SsLogoMark(size: 40),
                      const SizedBox(width: SsSpacing.md),
                      Text(
                        l10n.appTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.xxl),
                  LinearProgressIndicator(value: (_step + 1) / steps.length),
                  const SizedBox(height: SsSpacing.xxl),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Column(
                      key: ValueKey<int>(_step),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Icon(
                          current.icon,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: SsSpacing.xl),
                        Text(
                          current.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        Text(
                          current.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        if (_step == 2) ...<Widget>[
                          const SizedBox(height: SsSpacing.xl),
                          SsCard(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _confirmedPermission,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(l10n.onboardingConsentCheckbox),
                              onChanged: (bool? value) {
                                setState(() {
                                  _confirmedPermission = value ?? false;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: SsPrimaryButton(
                      label: _step == 2
                          ? l10n.getStartedAction
                          : l10n.continueAction,
                      onPressed: _step == 2 && !_confirmedPermission
                          ? null
                          : _next,
                    ),
                  ),
                  if (_step > 0) ...<Widget>[
                    const SizedBox(height: SsSpacing.sm),
                    SsTextAction(label: l10n.backAction, onPressed: _back),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
