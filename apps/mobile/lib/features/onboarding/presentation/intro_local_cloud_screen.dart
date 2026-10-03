/// A08 — Intro · Local vs Cloud · step 2/3.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/domain/models/entitlement.dart';
import 'widgets/onboarding_step_scaffold.dart';

class IntroLocalCloudScreen extends ConsumerWidget {
  const IntroLocalCloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool isIos =
        ref.watch(deviceInfoServiceProvider).platform == DevicePlatform.ios;
    return OnboardingStepScaffold(
      stepLabel: l10n.onboardingStepLabel(2, 3),
      title: l10n.introStorageTitle,
      body: l10n.introStorageBody,
      icon: Icons.save_alt_rounded,
      skipLabel: l10n.onboardingSkipAction,
      onSkip: () => context.go(AppRoutes.onboardingNotifications),
      primaryLabel: l10n.continueAction,
      onPrimary: () => context.go(AppRoutes.onboardingNotifications),
      child: Column(
        children: <Widget>[
          _StorageCard(
            chip: SsLocationChip(engine: Engine.local, label: l10n.localLabel),
            planLabel: l10n.freePlanLabel,
            title: l10n.introLocalTitle,
            bullets: <String>[
              l10n.introLocalBulletManual,
              l10n.introLocalBulletMinutes,
              isIos ? l10n.introLocalBulletIos : l10n.introLocalBulletAndroid,
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          _StorageCard(
            chip: SsLocationChip(engine: Engine.cloud, label: l10n.cloudLabel),
            planLabel: l10n.proPlanLabel,
            title: l10n.introCloudTitle,
            bullets: <String>[
              l10n.introCloudBulletServer,
              l10n.introCloudBulletAuto,
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.chip,
    required this.planLabel,
    required this.title,
    required this.bullets,
  });

  final Widget chip;
  final String planLabel;
  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: SsSpacing.sm,
            runSpacing: SsSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              chip,
              Text(planLabel, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: SsSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsSpacing.sm),
          for (final String bullet in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: SsSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: SsSpacing.sm),
                  Expanded(child: Text(bullet)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
