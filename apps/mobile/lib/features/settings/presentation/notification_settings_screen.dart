import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/notification_preferences.dart';
import 'controllers/notification_preferences_providers.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<NotificationPreferences> preferences = ref.watch(
      notificationPreferencesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: SafeArea(
        child: preferences.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(notificationPreferencesProvider),
            ),
          ),
          data: (NotificationPreferences value) => ListView(
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              Text(
                l10n.notificationsReleaseBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: SsSpacing.lg),
              SsCard(
                child: Column(
                  children: <Widget>[
                    _PreferenceSwitch(
                      title: l10n.notificationRecordingStartedTitle,
                      value: value.recordingStarted,
                      onChanged: (bool enabled) => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(value.copyWith(recordingStarted: enabled)),
                    ),
                    const Divider(),
                    _PreferenceSwitch(
                      title: l10n.notificationRecordingReadyTitle,
                      value: value.recordingReady,
                      onChanged: (bool enabled) => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(value.copyWith(recordingReady: enabled)),
                    ),
                    const Divider(),
                    _PreferenceSwitch(
                      title: l10n.notificationRecordingFailedTitle,
                      value: value.recordingFailed,
                      onChanged: (bool enabled) => ref
                          .read(notificationPreferencesProvider.notifier)
                          .update(value.copyWith(recordingFailed: enabled)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SsSpacing.md),
              Text(
                l10n.notificationsInAppOnlyBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
