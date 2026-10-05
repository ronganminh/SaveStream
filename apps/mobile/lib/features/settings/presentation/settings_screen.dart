import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import 'controllers/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    required this.settings,
    required this.session,
    required this.config,
    super.key,
  });

  final AppSettingsController settings;
  final AppSessionController session;
  final AppConfig config;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _accountBusy = false;
  bool _accountError = false;

  Future<void> _logout() async {
    await _runAccountAction(
      () =>
          ref.read(settingsAccountControllerProvider(widget.session)).logout(),
    );
  }

  Future<void> _deleteAccount() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await SsConfirmDialog.show(
      context,
      title: l10n.deleteAccountTitle,
      message: l10n.deleteAccountMessage,
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAccountAction,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _runAccountAction(
      () => ref
          .read(settingsAccountControllerProvider(widget.session))
          .deleteAccount(),
    );
  }

  Future<void> _runAccountAction(Future<void> Function() action) async {
    setState(() {
      _accountBusy = true;
      _accountError = false;
    });

    try {
      await action();
    } on Object {
      if (mounted) {
        setState(() {
          _accountError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _accountBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DevicePlatform platform = ref
        .watch(deviceInfoServiceProvider)
        .platform;
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final Entitlement? entitlementValue = entitlement.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SsSpacing.lg),
          children: <Widget>[
            if (_accountError) ...<Widget>[
              SsCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: SsSpacing.md),
                    Expanded(child: Text(l10n.accountActionError)),
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.lg),
            ],
            _SectionLabel(label: l10n.settingsPlanSectionTitle),
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              child: entitlement.when(
                loading: () =>
                    const SsSkeleton(height: 88, radius: SsRadii.lg),
                error: (Object error, StackTrace stackTrace) => SsListTile(
                  title: l10n.settingsPlanUnknownTitle,
                  subtitle: l10n.settingsPlanUnknownBody,
                  leading: const Icon(Icons.workspace_premium_outlined),
                ),
                data: (Entitlement data) => SsListTile(
                  title: data.plan == Plan.pro
                      ? l10n.settingsPlanProTitle
                      : l10n.settingsPlanFreeTitle,
                  subtitle: data.plan == Plan.pro
                      ? l10n.settingsPlanProBody(
                          data.cloudMinutesAvailable ~/ 60,
                          data.limits.maxWatches,
                        )
                      : l10n.settingsPlanFreeBody(
                          data.local.minutesRemaining,
                          data.watchCount,
                          data.limits.maxWatches,
                        ),
                  leading: Icon(
                    data.plan == Plan.pro
                        ? Icons.workspace_premium_rounded
                        : Icons.person_outline_rounded,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.usage),
                ),
              ),
            ),
            const SizedBox(height: SsSpacing.xl),
            _SectionLabel(label: l10n.settingsAccountSectionTitle),
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              child: Column(
                children: <Widget>[
                  SsListTile(
                    title: l10n.profileTitle,
                    subtitle: l10n.settingsProfileSubtitle,
                    leading: const Icon(Icons.person_outline_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.profile),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.securityAccountTitle,
                    subtitle: l10n.securityAccountSubtitle,
                    leading: const Icon(Icons.shield_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.securityAccount),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SsSpacing.xl),
            _SectionLabel(label: l10n.settingsPreferencesSectionTitle),
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              child: Column(
                children: <Widget>[
                  SsListTile(
                    title: l10n.languageTitle,
                    subtitle: widget.settings.locale.languageCode == 'vi'
                        ? l10n.languageVietnamese
                        : l10n.languageEnglish,
                    leading: const Icon(Icons.language_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.language),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.themeLabel,
                    subtitle: _themeLabel(l10n, widget.settings.themeMode),
                    leading: const Icon(Icons.contrast_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.theme),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.notificationsTitle,
                    subtitle: l10n.notificationsReleaseSubtitle,
                    leading: const Icon(Icons.notifications_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.deviceStorageTitle,
                    subtitle: l10n.deviceStorageSubtitle,
                    leading: const Icon(Icons.storage_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.deviceStorage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SsSpacing.xl),
            _SectionLabel(label: l10n.settingsSupportSectionTitle),
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              child: Column(
                children: <Widget>[
                  SsListTile(
                    title: l10n.helpTitle,
                    leading: const Icon(Icons.help_outline_rounded),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.help),
                  ),
                  const Divider(),
                  SsListTile(
                    title: l10n.legalHubTitle,
                    leading: const Icon(Icons.gavel_outlined),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.legalHub),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SsSpacing.xl),
            _SectionLabel(label: l10n.settingsRecordingSectionTitle),
            const SizedBox(height: SsSpacing.sm),
            SsCard(
              child: SsListTile(
                title: platform == DevicePlatform.android
                    ? l10n.settingsAndroidRecordingTitle
                    : l10n.settingsIosRecordingTitle,
                subtitle: platform == DevicePlatform.android
                    ? l10n.settingsAndroidRecordingSubtitle
                    : l10n.settingsIosRecordingSubtitle,
                leading: Icon(
                  platform == DevicePlatform.android
                      ? Icons.battery_alert
                      : Icons.phone_iphone_rounded,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  platform == DevicePlatform.android
                      ? AppRoutes.androidRecordingGuide
                      : AppRoutes.iosRecordingGuide,
                ),
              ),
            ),
            if (widget.config.developerToolsEnabled) ...<Widget>[
              const SizedBox(height: SsSpacing.xl),
              _SectionLabel(label: l10n.settingsDeveloperSectionTitle),
              const SizedBox(height: SsSpacing.sm),
              SsCard(
                child: SsListTile(
                  title: l10n.designSystemTitle,
                  leading: const Icon(Icons.palette_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.componentGallery),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => l10n.themeSystem,
    ThemeMode.light => l10n.themeLight,
    ThemeMode.dark => l10n.themeDark,
  };
}
