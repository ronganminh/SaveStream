/// AAccount · ASignOut — the Account tab: profile, Recording, Privacy &
/// safety, Help & legal, App, Account (sign out, delete) and the version.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../credits/presentation/credits_v2_parts.dart' show showCreditsToast;
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import 'account_parts.dart';
import 'account_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({
    required this.settings,
    required this.session,
    required this.config,
    super.key,
  });

  final AppSettingsController settings;
  final AppSessionController session;
  final AppConfig config;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAccountConfirmDialog(
      context,
      title: l10n.acSignOutTitle,
      body: l10n.acSignOutBody,
      cancelLabel: l10n.v2Cancel,
      confirmLabel: l10n.acSignOut,
      confirmKey: const ValueKey<String>('account-sign-out-confirm'),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await ref
          .read(settingsAccountControllerProvider(widget.session))
          .logout();
    } on Object {
      if (mounted) showCreditsToast(context, l10n.logoutFailedBody);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final UserProfile? profile = ref.watch(profileProvider).value;
    final Entitlement? entitlement = ref.watch(entitlementProvider).value;
    final String? version = ref.watch(appVersionProvider).value;
    final TextStyle footnote = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: palette.textMuted,
    );

    return SsV2Page(
      safeBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(title: l10n.acTitle),
          Expanded(
            child: ListView(
              key: const ValueKey<String>('account-list'),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                _ProfileHeader(
                  profile: profile,
                  onEdit: () => context.push(AppRoutes.profile),
                ),
                AccountSection(
                  label: l10n.acSectionRecording,
                  children: <Widget>[
                    AccountRow(
                      key: const ValueKey<String>('account-recording-time'),
                      glyph: SsV2IconGlyph.clock,
                      title: l10n.acRecordingTime,
                      subtitle: entitlement == null
                          ? null
                          : l10n.acTimeLeft(
                              formatRecordingMinutes(
                                l10n,
                                entitlement.cloudMinutesAvailable,
                              ),
                            ),
                      onTap: () => context.push(AppRoutes.usage),
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-purchases'),
                      glyph: SsV2IconGlyph.card,
                      title: l10n.crSettingsPurchases,
                      subtitle: l10n.acPurchasesSubtitle,
                      onTap: () => context.push(AppRoutes.purchases),
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-notifications'),
                      glyph: SsV2IconGlyph.bell,
                      title: l10n.notificationsTitle,
                      subtitle: l10n.acNotificationsSubtitle,
                      onTap: () =>
                          context.push(AppRoutes.notificationPreferences),
                    ),
                  ],
                ),
                AccountSection(
                  label: l10n.acSectionPrivacy,
                  children: <Widget>[
                    AccountRow(
                      key: const ValueKey<String>('account-ad-privacy'),
                      glyph: SsV2IconGlyph.ad,
                      title: l10n.crSettingsAdPrivacy,
                      subtitle: l10n.acAdPrivacySubtitle,
                      onTap: () => context.push(AppRoutes.adPrivacy),
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-report'),
                      glyph: SsV2IconGlyph.flag,
                      title: l10n.acReport,
                      onTap: () => context.push(AppRoutes.report),
                    ),
                  ],
                ),
                AccountSection(
                  label: l10n.acSectionHelp,
                  children: <Widget>[
                    AccountRow(
                      key: const ValueKey<String>('account-help'),
                      glyph: SsV2IconGlyph.help,
                      title: l10n.acHelpTitle,
                      onTap: () => context.push(AppRoutes.help),
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-legal'),
                      glyph: SsV2IconGlyph.document,
                      title: l10n.acLegalRow,
                      onTap: () => context.push(AppRoutes.legalHub),
                    ),
                  ],
                ),
                AccountSection(
                  label: l10n.acSectionAccount,
                  children: <Widget>[
                    AccountRow(
                      key: const ValueKey<String>('account-sign-out'),
                      glyph: SsV2IconGlyph.signOut,
                      title: l10n.acSignOut,
                      tone: AccountRowTone.neutral,
                      chevron: false,
                      trailing: _signingOut
                          ? const SsV2Spinner(size: 20, stroke: 2.5)
                          : null,
                      onTap: _signingOut ? null : _signOut,
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-delete'),
                      glyph: SsV2IconGlyph.trash,
                      title: l10n.acDeleteAccount,
                      subtitle: l10n.acDeleteAccountSubtitle,
                      tone: AccountRowTone.danger,
                      onTap: () => context.push(AppRoutes.deleteAccount),
                    ),
                  ],
                ),
                // Not drawn: language and theme stay reachable, below what is.
                AccountSection(
                  label: l10n.acSectionApp,
                  children: <Widget>[
                    AccountRow(
                      key: const ValueKey<String>('account-language'),
                      glyph: SsV2IconGlyph.globe,
                      title: l10n.languageTitle,
                      subtitle: _languageLabel(l10n, widget.settings),
                      onTap: () => context.push(AppRoutes.language),
                    ),
                    AccountRow(
                      key: const ValueKey<String>('account-theme'),
                      glyph: SsV2IconGlyph.moon,
                      title: l10n.themeLabel,
                      subtitle: switch (widget.settings.themeMode) {
                        ThemeMode.system => l10n.themeSystem,
                        ThemeMode.light => l10n.themeLight,
                        ThemeMode.dark => l10n.themeDark,
                      },
                      onTap: () => context.push(AppRoutes.theme),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                  child: Column(
                    children: <Widget>[
                      if (version != null)
                        Text(
                          l10n.acVersion(version),
                          key: const ValueKey<String>('account-version'),
                          textAlign: TextAlign.center,
                          style: footnote.copyWith(height: 1.26),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.v2NotAffiliated,
                        textAlign: TextAlign.center,
                        style: footnote,
                      ),
                    ],
                  ),
                ),
              ], 16),
            ),
          ),
        ],
      ),
    );
  }
}

String _languageLabel(AppLocalizations l10n, AppSettingsController settings) {
  if (settings.useSystemLocale) return l10n.languageSystem;
  return settings.locale.languageCode == 'vi'
      ? l10n.languageVietnamese
      : l10n.languageEnglish;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit});

  final UserProfile? profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final UserProfile? data = profile;
    final String name = data == null
        ? ''
        : (data.displayName ?? l10n.profileFallbackName);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          if (data == null)
            const SsV2Skeleton(width: 60, height: 60, radius: 30)
          else
            SsV2Avatar(
              name: data.displayName ?? data.email,
              size: 60,
              fontSize: 21,
              brand: true,
            ),
          const SizedBox(width: 14),
          Expanded(
            child: data == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SsV2Skeleton(width: 140, height: 20),
                      SizedBox(height: 6),
                      SsV2Skeleton(width: 190, height: 14),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 14),
          SsV2Button(
            key: const ValueKey<String>('account-edit'),
            label: l10n.acEdit,
            variant: SsV2ButtonVariant.outlined,
            size: SsV2ButtonSize.small,
            expand: false,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}
