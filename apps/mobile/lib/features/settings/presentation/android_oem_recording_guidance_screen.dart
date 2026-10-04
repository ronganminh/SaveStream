/// AN03 — Android OEM-specific background recording guidance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/recording_platform_service.dart';
import '../../../platform/platform_providers.dart';

class AndroidOemRecordingGuidanceScreen extends ConsumerWidget {
  const AndroidOemRecordingGuidanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AndroidRecordingPlatformState>(
      future: ref.watch(recordingPlatformServiceProvider).androidState,
      builder: (BuildContext context, snapshot) {
        final AndroidRecordingPlatformState? state = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state == null
                  ? context.l10n.androidOemGuideAction
                  : context.l10n.androidOemGuideTitle(state.deviceName),
            ),
          ),
          body: state == null
              ? const _OemSkeleton()
              : _OemBody(state: state),
        );
      },
    );
  }
}

class _OemBody extends ConsumerWidget {
  const _OemBody({required this.state});

  final AndroidRecordingPlatformState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> steps = switch (state.oemFamily) {
      AndroidOemFamily.xiaomi => <String>[
        context.l10n.androidOemAutostartStep,
        context.l10n.androidOemBatteryStep,
        context.l10n.androidOemRecentAppsStep,
      ],
      AndroidOemFamily.samsung => <String>[
        context.l10n.androidOemSamsungSleepStep,
        context.l10n.androidOemBatteryStep,
      ],
      AndroidOemFamily.oppoRealmeVivo ||
      AndroidOemFamily.huawei => <String>[
        context.l10n.androidOemAppLaunchStep,
        context.l10n.androidOemBatteryStep,
        context.l10n.androidOemRecentAppsStep,
      ],
      AndroidOemFamily.generic => <String>[
        context.l10n.androidOemBatteryStep,
        context.l10n.androidOemRecentAppsStep,
      ],
    };
    final String body = switch (state.oemFamily) {
      AndroidOemFamily.xiaomi => context.l10n.androidOemXiaomiBody,
      AndroidOemFamily.samsung => context.l10n.androidOemSamsungBody,
      AndroidOemFamily.oppoRealmeVivo => context.l10n.androidOemOppoBody,
      AndroidOemFamily.huawei => context.l10n.androidOemHuaweiBody,
      AndroidOemFamily.generic => context.l10n.androidOemGenericBody,
    };

    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        SsInlineAlert(
          title: state.osName ?? state.deviceName,
          message: body,
          tone: SsInlineAlertTone.warning,
        ),
        const SizedBox(height: SsSpacing.lg),
        SsChecklist(
          items: <SsChecklistItem>[
            for (final String step in steps) SsChecklistItem(label: step),
          ],
        ),
        const SizedBox(height: SsSpacing.lg),
        SsPrimaryButton(
          label: context.l10n.androidOpenAppSettingsAction,
          icon: Icons.settings_outlined,
          onPressed: () =>
              ref.read(recordingPlatformServiceProvider).openAppSettings(),
        ),
        const SizedBox(height: SsSpacing.sm),
        SsSecondaryButton(
          label: context.l10n.doneAction,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _OemSkeleton extends StatelessWidget {
  const _OemSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 96, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 164, radius: SsRadii.lg),
      ],
    );
  }
}
