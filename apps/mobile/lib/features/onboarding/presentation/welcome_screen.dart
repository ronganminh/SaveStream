import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

/// A02 — Welcome. First screen for a signed-out install: value proposition,
/// a preview of a running recording, and the two entry points into auth.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.session,
    required this.settings,
    required this.config,
    super.key,
  });

  final AppSessionController session;
  final AppSettingsController settings;
  final AppConfig config;

  void _continueTo(BuildContext context, String route) {
    session.completeOnboarding();
    context.go(route);
  }

  void _toggleLanguage() {
    settings.setLocale(
      settings.locale.languageCode == 'vi'
          ? const Locale('en')
          : const Locale('vi'),
    );
  }

  void _cycleTheme() {
    settings.setThemeMode(switch (settings.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String themeName = switch (settings.themeMode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    };

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
                      Text(l10n.appTitle, style: theme.textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.xxl),
                  Text(
                    l10n.welcomeHeadline,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Text(
                    l10n.welcomeBody,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  const _RecordingPreview(),
                  const SizedBox(height: SsSpacing.xxl),
                  SsPrimaryButton(
                    label: l10n.createAccountAction,
                    onPressed: () => _continueTo(context, AppRoutes.register),
                  ),
                  const SizedBox(height: SsSpacing.md),
                  SsSecondaryButton(
                    label: l10n.signInAction,
                    onPressed: () => _continueTo(context, AppRoutes.signIn),
                  ),
                  const SizedBox(height: SsSpacing.lg),
                  Text(
                    l10n.welcomeLegalNotice,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => launchUrl(
                          config.termsOfUseUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(l10n.termsOfUseTitle),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          config.privacyPolicyUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(l10n.privacyPolicyTitle),
                      ),
                    ],
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: SsSpacing.sm,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: _toggleLanguage,
                        icon: const Icon(Icons.language_rounded, size: 18),
                        label: Text(
                          settings.locale.languageCode == 'vi'
                              ? l10n.languageVietnamese
                              : l10n.languageEnglish,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _cycleTheme,
                        icon: const Icon(Icons.contrast_rounded, size: 18),
                        label: Text(l10n.welcomeThemeLabel(themeName)),
                      ),
                    ],
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

/// Illustration built from real components so it follows theme and locale.
class _RecordingPreview extends StatelessWidget {
  const _RecordingPreview();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ExcludeSemantics(
      child: SsCard(
        child: Row(
          children: <Widget>[
            const SsAvatar(label: 'Lina Studio'),
            const SizedBox(width: SsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('@linastudio', style: theme.textTheme.titleSmall),
                  Text(
                    l10n.welcomePreviewStatus,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SsSpacing.sm),
            SsStatusChip(label: l10n.liveStatus, tone: SsStatusTone.recording),
          ],
        ),
      ),
    );
  }
}
