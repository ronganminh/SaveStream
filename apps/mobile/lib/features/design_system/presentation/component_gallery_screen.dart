import 'package:flutter/material.dart';

import '../../../features/entitlement/domain/models/entitlement.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';

class ComponentGalleryScreen extends StatelessWidget {
  const ComponentGalleryScreen({
    required this.config,
    required this.settings,
    super.key,
  });

  final AppConfig config;
  final AppSettingsController settings;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            SsSpacing.lg,
            SsSpacing.sm,
            SsSpacing.lg,
            SsSpacing.xxxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.designSystemTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: SsSpacing.sm),
                  Text(
                    l10n.designSystemSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SsStatusChip(
                      label:
                          l10n.environmentLabel +
                          ': ' +
                          config.environment.label,
                    ),
                  ),
                  const SizedBox(height: SsSpacing.xl),
                  _PreferenceCard(settings: settings),
                  const SizedBox(height: SsSpacing.xl),
                  _GallerySection(
                    title: l10n.buttonsSection,
                    child: Wrap(
                      spacing: SsSpacing.md,
                      runSpacing: SsSpacing.md,
                      children: <Widget>[
                        SsPrimaryButton(
                          label: l10n.primaryAction,
                          icon: Icons.add_rounded,
                          onPressed: () {},
                        ),
                        SsSecondaryButton(
                          label: l10n.secondaryAction,
                          icon: Icons.tune_rounded,
                          onPressed: () {},
                        ),
                        SsTextAction(label: l10n.textAction, onPressed: () {}),
                        SsIconButton(
                          icon: Icons.more_horiz_rounded,
                          tooltip: l10n.textAction,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  _GallerySection(
                    title: l10n.fieldsSection,
                    child: Column(
                      children: <Widget>[
                        SsTextField(
                          label: l10n.emailLabel,
                          hintText: l10n.emailHint,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsPasswordField(label: l10n.passwordLabel),
                      ],
                    ),
                  ),
                  _GallerySection(
                    title: l10n.surfacesSection,
                    child: SsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SsSectionHeader(
                            title: l10n.sectionExampleTitle,
                            actionLabel: l10n.sectionExampleAction,
                            onAction: () {},
                          ),
                          SsListTile(
                            title: l10n.creatorName,
                            subtitle: l10n.creatorSubtitle,
                            leading: SsAvatar(label: l10n.creatorName),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {},
                          ),
                          const Divider(),
                          Wrap(
                            spacing: SsSpacing.sm,
                            runSpacing: SsSpacing.sm,
                            children: <Widget>[
                              SsStatusChip(
                                label: l10n.readyStatus,
                                tone: SsStatusTone.success,
                                icon: Icons.check_circle_outline_rounded,
                              ),
                              SsStatusChip(
                                label: l10n.recordingStatus,
                                tone: SsStatusTone.recording,
                                icon: Icons.fiber_manual_record_rounded,
                              ),
                              SsStatusChip(
                                label: l10n.warningStatus,
                                tone: SsStatusTone.warning,
                                icon: Icons.warning_amber_rounded,
                              ),
                              SsStatusChip(
                                label: l10n.errorStatus,
                                tone: SsStatusTone.error,
                                icon: Icons.error_outline_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _GallerySection(
                    title: 'V2 A0',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Wrap(
                          spacing: SsSpacing.sm,
                          runSpacing: SsSpacing.sm,
                          children: <Widget>[
                            SsLocationChip(engine: Engine.local),
                            SsLocationChip(engine: Engine.cloud),
                            SsPlanBadge(plan: Plan.free),
                            SsPlanBadge(plan: Plan.pro),
                            SsLiveBadge(isLive: true),
                          ],
                        ),
                        const SizedBox(height: SsSpacing.md),
                        const SsQuotaCard(
                          title: 'Cloud time',
                          value: '133 h 20 min',
                          subtitle: '3 / 20 creators',
                          progress: .45,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsInlineAlert(
                          title: l10n.warningStatus,
                          message: l10n.errorBody,
                          tone: SsInlineAlertTone.warning,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsFilterChips(
                          items: const <String>['All', 'LIVE', 'Offline'],
                          selectedIndex: 0,
                          onSelected: (_) {},
                        ),
                        const SizedBox(height: SsSpacing.md),
                        const SsBannerAdSlot(label: 'Ad slot'),
                        const SizedBox(height: SsSpacing.md),
                        SsCreatorTile(
                          name: l10n.creatorName,
                          handle: l10n.creatorSubtitle,
                          isLive: true,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsRecordingTile(
                          title: l10n.creatorName,
                          subtitle: '01:23:45',
                          engine: Engine.cloud,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsActiveRecordingCard(
                          creatorName: l10n.creatorName,
                          elapsed: '00:12:34',
                          engine: Engine.local,
                        ),
                        const SizedBox(height: SsSpacing.md),
                        const SsRecordingBar(
                          label: '1 recording active',
                          elapsed: '00:12:34',
                        ),
                        const SizedBox(height: SsSpacing.md),
                        const SsChecklist(
                          items: <SsChecklistItem>[
                            SsChecklistItem(label: 'Finalize file', done: true),
                            SsChecklistItem(label: 'Save metadata'),
                          ],
                        ),
                        const SizedBox(height: SsSpacing.md),
                        Wrap(
                          spacing: SsSpacing.sm,
                          runSpacing: SsSpacing.sm,
                          children: <Widget>[
                            SsSecondaryButton(
                              label: l10n.showDialogAction,
                              onPressed: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SsBottomSheet(
                                      title: l10n.confirmTitle,
                                      child: Text(l10n.confirmBody),
                                    );
                                  },
                                );
                              },
                            ),
                            SsSecondaryButton(
                              label: l10n.showSnackbarAction,
                              onPressed: () {
                                SsToast.show(context, l10n.snackbarMessage);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _GallerySection(
                    title: l10n.statesSection,
                    child: Column(
                      children: <Widget>[
                        SsCard(
                          child: SsEmptyState(
                            title: l10n.emptyTitle,
                            message: l10n.emptyBody,
                          ),
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsCard(
                          child: SsErrorState(
                            title: l10n.errorTitle,
                            message: l10n.errorBody,
                            retryLabel: l10n.retryAction,
                            onRetry: () {},
                          ),
                        ),
                        const SizedBox(height: SsSpacing.md),
                        SsCard(child: SsLoadingView(label: l10n.loadingLabel)),
                        const SizedBox(height: SsSpacing.md),
                        const SsCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SsSkeleton(width: 180, height: 20),
                              SizedBox(height: SsSpacing.md),
                              SsSkeleton(height: 14),
                              SizedBox(height: SsSpacing.sm),
                              SsSkeleton(width: 240, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _GallerySection(
                    title: l10n.feedbackSection,
                    child: Wrap(
                      spacing: SsSpacing.md,
                      runSpacing: SsSpacing.md,
                      children: <Widget>[
                        SsSecondaryButton(
                          label: l10n.showDialogAction,
                          onPressed: () async {
                            await SsConfirmDialog.show(
                              context,
                              title: l10n.confirmTitle,
                              message: l10n.confirmBody,
                              cancelLabel: l10n.cancelAction,
                              confirmLabel: l10n.confirmAction,
                            );
                          },
                        ),
                        SsPrimaryButton(
                          label: l10n.showSnackbarAction,
                          onPressed: () {
                            SsSnackbar.show(context, l10n.snackbarMessage);
                          },
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.componentGalleryHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
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

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l10n.themeLabel, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: SsSpacing.sm),
          Wrap(
            spacing: SsSpacing.sm,
            children: <Widget>[
              _ThemeChoice(
                label: l10n.themeSystem,
                value: ThemeMode.system,
                settings: settings,
              ),
              _ThemeChoice(
                label: l10n.themeLight,
                value: ThemeMode.light,
                settings: settings,
              ),
              _ThemeChoice(
                label: l10n.themeDark,
                value: ThemeMode.dark,
                settings: settings,
              ),
            ],
          ),
          const SizedBox(height: SsSpacing.xl),
          Text(
            l10n.languageLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SsSpacing.sm),
          Wrap(
            spacing: SsSpacing.sm,
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.languageEnglish),
                selected: settings.locale.languageCode == 'en',
                onSelected: (_) => settings.setLocale(const Locale('en')),
              ),
              ChoiceChip(
                label: Text(l10n.languageVietnamese),
                selected: settings.locale.languageCode == 'vi',
                onSelected: (_) => settings.setLocale(const Locale('vi')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.value,
    required this.settings,
  });

  final String label;
  final ThemeMode value;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: settings.themeMode == value,
      onSelected: (_) => settings.setThemeMode(value),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SsSpacing.md),
          child,
        ],
      ),
    );
  }
}
