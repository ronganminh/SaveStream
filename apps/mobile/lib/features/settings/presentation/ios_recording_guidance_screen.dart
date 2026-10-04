/// IO03 — iPhone Local recording guidance and return reminder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/platform_providers.dart';

class IosRecordingGuidanceScreen extends ConsumerStatefulWidget {
  const IosRecordingGuidanceScreen({super.key});

  @override
  ConsumerState<IosRecordingGuidanceScreen> createState() =>
      _IosRecordingGuidanceScreenState();
}

class _IosRecordingGuidanceScreenState
    extends ConsumerState<IosRecordingGuidanceScreen> {
  bool? _reminderEnabled;

  @override
  void initState() {
    super.initState();
    _loadReminder();
  }

  Future<void> _loadReminder() async {
    final bool enabled =
        await ref.read(recordingPlatformServiceProvider).iosReturnReminderEnabled;
    if (mounted) {
      setState(() => _reminderEnabled = enabled);
    }
  }

  Future<void> _setReminder(bool enabled) async {
    setState(() => _reminderEnabled = enabled);
    await ref
        .read(recordingPlatformServiceProvider)
        .setIosReturnReminderEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final bool? reminderEnabled = _reminderEnabled;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.iosRecordingGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SsSpacing.lg),
        children: <Widget>[
          SsInlineAlert(
            title: context.l10n.iosKeepOpenTitle,
            message: context.l10n.iosKeepOpenBody,
            tone: SsInlineAlertTone.warning,
          ),
          const SizedBox(height: SsSpacing.lg),
          SsCard(
            child: Column(
              children: <Widget>[
                SsListTile(
                  title: context.l10n.iosScreenAwakeTitle,
                  subtitle: context.l10n.iosScreenAwakeBody,
                  leading: const Icon(Icons.screen_lock_portrait_outlined),
                ),
                const Divider(),
                SsListTile(
                  title: context.l10n.iosRecoveryGuideTitle,
                  subtitle: context.l10n.iosRecoveryGuideBody,
                  leading: const Icon(Icons.restore_rounded),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.iosReturnReminderTitle),
                  subtitle: Text(context.l10n.iosReturnReminderBody),
                  secondary: const Icon(Icons.notifications_outlined),
                  value: reminderEnabled ?? false,
                  onChanged: reminderEnabled == null ? null : _setReminder,
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.lg),
          SsInlineAlert(
            title: context.l10n.iosCloudIndependentTitle,
            message: context.l10n.iosCloudIndependentBody,
          ),
          const SizedBox(height: SsSpacing.sm),
          SsTextAction(
            label: context.l10n.buyCloudHoursAction,
            icon: Icons.cloud_outlined,
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ],
      ),
    );
  }
}
