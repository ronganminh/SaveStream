/// AN02 — Android background recording battery guidance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/recording_platform_service.dart';
import '../../../platform/platform_providers.dart';

class AndroidRecordingBackgroundScreen extends ConsumerStatefulWidget {
  const AndroidRecordingBackgroundScreen({super.key});

  @override
  ConsumerState<AndroidRecordingBackgroundScreen> createState() =>
      _AndroidRecordingBackgroundScreenState();
}

class _AndroidRecordingBackgroundScreenState
    extends ConsumerState<AndroidRecordingBackgroundScreen>
    with WidgetsBindingObserver {
  late Future<AndroidRecordingPlatformState> _stateFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_refresh);
    }
  }

  void _refresh() {
    _stateFuture = ref.read(recordingPlatformServiceProvider).androidState;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.androidBackgroundGuideTitle)),
      body: FutureBuilder<AndroidRecordingPlatformState>(
        future: _stateFuture,
        builder: (BuildContext context, snapshot) {
          if (!snapshot.hasData) {
            return const _GuidanceSkeleton();
          }
          final AndroidRecordingPlatformState state = snapshot.data!;
          final bool unrestricted =
              state.batteryMode == AndroidBatteryMode.unrestricted;

          return ListView(
            padding: const EdgeInsets.all(SsSpacing.lg),
            children: <Widget>[
              SsInlineAlert(
                title: context.l10n.androidBatteryOptimizationTitle,
                message: unrestricted
                    ? context.l10n.androidBatteryOptimizationOff
                    : context.l10n.androidBatteryOptimizationBody,
                tone: unrestricted
                    ? SsInlineAlertTone.success
                    : SsInlineAlertTone.warning,
              ),
              const SizedBox(height: SsSpacing.lg),
              SsChecklist(
                items: <SsChecklistItem>[
                  SsChecklistItem(
                    label: context.l10n.androidBatteryStepOpen,
                    done: unrestricted,
                    active: !unrestricted,
                  ),
                  SsChecklistItem(
                    label: context.l10n.androidBatteryStepUnrestricted,
                    done: unrestricted,
                  ),
                  SsChecklistItem(
                    label: context.l10n.androidBatteryStepReturn,
                    done: unrestricted,
                  ),
                ],
              ),
              if (!unrestricted) ...<Widget>[
                const SizedBox(height: SsSpacing.lg),
                SsPrimaryButton(
                  label: context.l10n.androidOpenBatterySettingsAction,
                  icon: Icons.battery_alert,
                  onPressed: () => ref
                      .read(recordingPlatformServiceProvider)
                      .openBatterySettings(),
                ),
              ],
              if (state.oemFamily != AndroidOemFamily.generic) ...<Widget>[
                const SizedBox(height: SsSpacing.md),
                SsSecondaryButton(
                  label: context.l10n.androidOemGuideAction,
                  icon: Icons.smartphone_rounded,
                  onPressed: () =>
                      context.push(AppRoutes.androidOemRecordingGuide),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GuidanceSkeleton extends StatelessWidget {
  const _GuidanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(height: 96, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 164, radius: SsRadii.lg),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 48, radius: SsRadii.md),
      ],
    );
  }
}
