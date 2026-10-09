import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/recording_platform_service.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../store/presentation/a5_purchase_controller.dart';
import '../domain/models/user_profile.dart';
import 'controllers/settings_providers.dart';
import 'device_storage_screen.dart';
import 'notification_action_button.dart';

final FutureProvider<AndroidRecordingPlatformState>
androidRecordingStateProvider = FutureProvider<AndroidRecordingPlatformState>(
  (Ref ref) => ref.watch(recordingPlatformServiceProvider).androidState,
);

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
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DevicePlatform platform = ref
        .watch(deviceInfoServiceProvider)
        .platform;
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AsyncValue<UserProfile> profile = ref.watch(profileProvider);
    final AsyncValue<DeviceStorageSnapshot> storage = ref.watch(
      deviceStorageSnapshotProvider,
    );
    final Entitlement? access = entitlement.value;
    final bool isPro = access?.plan == Plan.pro;
    final bool canRecordLocal = access?.local.enabled ?? true;
    final AsyncValue<AndroidRecordingPlatformState>? androidRecording =
        platform == DevicePlatform.android
        ? ref.watch(androidRecordingStateProvider)
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SsLargeHeader(
              title: l10n.settingsTitle,
              actions: const <Widget>[NotificationActionButton()],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SsSpacing.lg,
                  0,
                  SsSpacing.lg,
                  SsSpacing.xxl,
                ),
                children: <Widget>[
                  _ProfileSummary(
                    profile: profile,
                    entitlement: entitlement,
                    onUsage: () => context.push(AppRoutes.usage),
                    onUpgrade: () => context.push(
                      AppRoutes.cloudHoursLocation(
                        CloudHoursPurchaseContext.removeAds.name,
                      ),
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  _SectionLabel(label: l10n.settingsRecordingSectionTitle),
                  const SizedBox(height: SsSpacing.sm),
                  SsCard(
                    child: Column(
                      children: <Widget>[
                        if (isPro) ...<Widget>[
                          SsListTile(
                            title: l10n.settingsAutoRecordDefaultTitle,
                            subtitle: l10n.autoRecordCloudLocation,
                            leading: const Icon(Icons.cloud_done_rounded),
                          ),
                          const Divider(),
                          SsListTile(
                            title: l10n.settingsCloudRetentionTitle,
                            subtitle: l10n.cloudRetentionValue(
                              access!.limits.cloudRetentionDays,
                            ),
                            leading: const Icon(Icons.schedule_rounded),
                          ),
                          const Divider(),
                          SsListTile(
                            title: l10n.settingsLocalRecordingTitle,
                            subtitle: !canRecordLocal
                                ? l10n.settingsLocalRecordingDisabledValue
                                : access.local.unlimited
                                ? l10n.settingsLocalRecordingUnlimitedValue
                                : l10n.settingsLocalRecordingAvailableValue,
                            leading: const Icon(Icons.smartphone_rounded),
                          ),
                          const Divider(),
                        ],
                        SsListTile(
                          title: l10n.deviceStorageTitle,
                          subtitle: storage.value == null
                              ? l10n.deviceStorageSubtitle
                              : formatFileSize(storage.value!.localBytes),
                          leading: const Icon(Icons.storage_rounded),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoutes.deviceStorage),
                        ),
                        if (canRecordLocal) ...<Widget>[
                          const Divider(),
                          SsListTile(
                            title: l10n.settingsRecordingQualityTitle,
                            subtitle: l10n.settingsRecordingQualityValue,
                            leading: const Icon(Icons.high_quality_rounded),
                          ),
                          const Divider(),
                          SsListTile(
                            title: platform == DevicePlatform.android
                                ? l10n.settingsAndroidRecordingTitle
                                : l10n.settingsIosRecordingTitle,
                            subtitle: _backgroundRecordingSubtitle(
                              l10n,
                              platform,
                              androidRecording,
                            ),
                            leading: Icon(
                              platform == DevicePlatform.android
                                  ? Icons.battery_saver_rounded
                                  : Icons.phone_iphone_rounded,
                            ),
                            trailing: _backgroundRecordingTrailing(
                              context,
                              platform,
                              androidRecording,
                            ),
                            onTap: () => context.push(
                              platform == DevicePlatform.android
                                  ? AppRoutes.androidRecordingGuide
                                  : AppRoutes.iosRecordingGuide,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  _SectionLabel(label: l10n.settingsAppSectionTitle),
                  const SizedBox(height: SsSpacing.sm),
                  SsCard(
                    child: Column(
                      children: <Widget>[
                        SsListTile(
                          title: l10n.notificationsTitle,
                          subtitle: l10n.notificationsReleaseSubtitle,
                          leading: const Icon(Icons.notifications_outlined),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoutes.notifications),
                        ),
                        const Divider(),
                        SsListTile(
                          title: l10n.themeLabel,
                          subtitle: _themeLabel(
                            l10n,
                            widget.settings.themeMode,
                          ),
                          leading: const Icon(Icons.contrast_rounded),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoutes.theme),
                        ),
                        const Divider(),
                        SsListTile(
                          title: l10n.languageTitle,
                          subtitle: widget.settings.locale.languageCode == 'vi'
                              ? l10n.languageVietnamese
                              : l10n.languageEnglish,
                          leading: const Icon(Icons.language_rounded),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(AppRoutes.language),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  _SectionLabel(label: l10n.settingsPurchasesSectionTitle),
                  const SizedBox(height: SsSpacing.sm),
                  SsCard(
                    child: Column(
                      children: <Widget>[
                        SsListTile(
                          title: l10n.buyCloudHoursAction,
                          leading: const Icon(Icons.add_shopping_cart_rounded),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            AppRoutes.cloudHoursLocation(
                              CloudHoursPurchaseContext.autoRecord.name,
                            ),
                          ),
                        ),
                        const Divider(),
                        SsListTile(
                          title: l10n.restorePurchasesAction,
                          leading: const Icon(Icons.restore_rounded),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(
                            AppRoutes.cloudHoursLocation(
                              CloudHoursPurchaseContext.autoRecord.name,
                            ),
                          ),
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
          ],
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({
    required this.profile,
    required this.entitlement,
    required this.onUsage,
    required this.onUpgrade,
  });

  final AsyncValue<UserProfile> profile;
  final AsyncValue<Entitlement> entitlement;
  final VoidCallback onUsage;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsCard(
      child: profile.when(
        loading: () => const SsSkeleton(height: 72, radius: SsRadii.lg),
        error: (Object error, StackTrace stackTrace) => SsListTile(
          title: l10n.profileTitle,
          subtitle: l10n.settingsProfileSubtitle,
          leading: const Icon(Icons.person_outline_rounded),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(AppRoutes.profile),
        ),
        data: (UserProfile data) {
          final Entitlement? access = entitlement.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: () => context.push(AppRoutes.profile),
                child: Row(
                  children: <Widget>[
                    SsAvatar(label: data.displayName ?? data.email, radius: 24),
                    const SizedBox(width: SsSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            data.displayName ?? l10n.profileFallbackName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            data.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SsSpacing.sm),
                    if (access == null)
                      const Icon(Icons.chevron_right_rounded)
                    else
                      SsPlanBadge(plan: access.plan),
                  ],
                ),
              ),
              const Divider(),
              if (access == null)
                const SsSkeleton(height: 68, radius: SsRadii.md)
              else ...<Widget>[
                if (access.plan == Plan.pro)
                  _ProUsageSummary(access: access)
                else
                  Row(
                    children: <Widget>[
                      Text(l10n.settingsTodayLabel),
                      const SizedBox(width: SsSpacing.sm),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            l10n.settingsDailyUsageValue(
                              access.local.minutesRemaining,
                              access.local.dailyMinutes,
                              access.local.rewardsUsedToday,
                              access.local.rewardsCapPerDay,
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: SsSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onUsage,
                        child: Text(l10n.settingsPlanSectionTitle),
                      ),
                    ),
                    if (access.plan == Plan.free) ...<Widget>[
                      const SizedBox(width: SsSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed: onUpgrade,
                          child: Text(l10n.upgradeToProAction),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProUsageSummary extends StatelessWidget {
  const _ProUsageSummary({required this.access});

  final Entitlement access;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.settingsPlanProTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: SsSpacing.xs),
        Text(
          formatMinutesAsHoursMinutes(
            access.cloudMinutesAvailable,
            hoursLabel: l10n.timeHoursUnit,
            minutesLabel: l10n.timeMinutesUnit,
          ),
        ),
        Text(l10n.watchUsage(access.watchCount, access.limits.maxWatches)),
        Text(
          !access.local.enabled
              ? l10n.settingsLocalRecordingDisabledValue
              : access.local.unlimited
              ? l10n.settingsLocalRecordingUnlimitedValue
              : l10n.settingsLocalRecordingAvailableValue,
        ),
      ],
    );
  }
}

String _backgroundRecordingSubtitle(
  AppLocalizations l10n,
  DevicePlatform platform,
  AsyncValue<AndroidRecordingPlatformState>? state,
) {
  if (platform != DevicePlatform.android) {
    return l10n.settingsIosRecordingSubtitle;
  }
  final AndroidBatteryMode? mode = state?.value?.batteryMode;
  return mode == AndroidBatteryMode.unrestricted
      ? l10n.androidBatteryOptimizationOff
      : l10n.settingsAndroidRecordingSubtitle;
}

Widget _backgroundRecordingTrailing(
  BuildContext context,
  DevicePlatform platform,
  AsyncValue<AndroidRecordingPlatformState>? state,
) {
  if (platform != DevicePlatform.android) {
    return const Icon(Icons.chevron_right_rounded);
  }
  final bool unrestricted =
      state?.value?.batteryMode == AndroidBatteryMode.unrestricted;
  if (unrestricted) {
    return Icon(
      Icons.check_circle_rounded,
      color: Theme.of(context).colorScheme.primary,
    );
  }
  return const Icon(Icons.warning_amber_rounded);
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
