/// A09 — Notification rationale · step 3/3.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import 'widgets/onboarding_step_scaffold.dart';

class NotificationRationaleScreen extends ConsumerStatefulWidget {
  const NotificationRationaleScreen({super.key});

  @override
  ConsumerState<NotificationRationaleScreen> createState() =>
      _NotificationRationaleScreenState();
}

class _NotificationRationaleScreenState
    extends ConsumerState<NotificationRationaleScreen> {
  bool _requesting = false;

  void _continue() {
    final DevicePlatform platform = ref
        .read(deviceInfoServiceProvider)
        .platform;
    context.go(
      platform == DevicePlatform.android
          ? AppRoutes.onboardingAndroidPermission
          : AppRoutes.onboardingIosLimits,
    );
  }

  Future<void> _requestPermission() async {
    setState(() {
      _requesting = true;
    });
    await ref.read(pushServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() {
      _requesting = false;
    });
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return OnboardingStepScaffold(
      stepLabel: l10n.onboardingStepLabel(3, 3),
      title: l10n.notificationRationaleTitle,
      body: l10n.notificationRationaleBody,
      icon: Icons.notifications_active_outlined,
      primaryLabel: l10n.enableNotificationsAction,
      primaryLoading: _requesting,
      onPrimary: _requestPermission,
      secondaryLabel: l10n.laterAction,
      onSecondary: _requesting ? null : _continue,
      child: Column(
        children: <Widget>[
          _ReasonRow(
            icon: Icons.radio_button_checked_rounded,
            text: l10n.notificationRationaleFollowedOnly,
          ),
          const SizedBox(height: SsSpacing.md),
          _ReasonRow(
            icon: Icons.tune_rounded,
            text: l10n.notificationRationalePerCreator,
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: SsSpacing.md),
        Expanded(child: Text(text)),
      ],
    );
  }
}
