import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/formatters/v2_formatters.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/device_info_service.dart';
import '../../../platform/contracts/local_recovery_service.dart';
import '../../../platform/platform_providers.dart';
import 'controllers/local_recovery_providers.dart';

class LocalRecoveryScreen extends ConsumerStatefulWidget {
  const LocalRecoveryScreen({super.key});

  @override
  ConsumerState<LocalRecoveryScreen> createState() =>
      _LocalRecoveryScreenState();
}

class _LocalRecoveryScreenState extends ConsumerState<LocalRecoveryScreen> {
  bool _recovering = false;
  LocalRecoveryResult? _result;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<LocalRecoveryCandidate?> candidate = ref.watch(
      interruptedLocalRecordingProvider,
    );
    final DevicePlatform platform = ref.watch(deviceInfoServiceProvider).platform;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(context.l10n.localRecoveryTitle),
      ),
      body: SafeArea(
        child: candidate.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(interruptedLocalRecordingProvider),
            ),
          ),
          data: (LocalRecoveryCandidate? value) {
            final LocalRecoveryResult? result = _result;
            if (result != null) {
              return _RecoveryResultBody(
                result: result,
                platform: platform,
                onDeleteTemporary: () => _deleteTemporary(result.candidate),
              );
            }
            if (_recovering && value != null) {
              return _RecoveringBody(candidate: value);
            }
            if (value == null) {
              return _NoRecoveryBody(
                onHome: () => context.go(AppRoutes.home),
              );
            }
            return _InterruptedBody(
              candidate: value,
              platform: platform,
              errorMessage: _errorMessage,
              onRecover: () => _recover(value),
              onLater: () => context.go(AppRoutes.home),
            );
          },
        ),
      ),
    );
  }

  Future<void> _recover(LocalRecoveryCandidate candidate) async {
    if (_recovering) return;
    setState(() {
      _recovering = true;
      _errorMessage = null;
    });
    try {
      final LocalRecoveryResult result = await ref
          .read(localRecoveryServiceProvider)
          .recover(candidate);
      if (!mounted) return;
      setState(() {
        _recovering = false;
        _result = result;
      });
      if (result.outcome != LocalRecoveryOutcome.failed) {
        ref.invalidate(interruptedLocalRecordingProvider);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _recovering = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _deleteTemporary(LocalRecoveryCandidate candidate) async {
    await ref
        .read(localRecoveryServiceProvider)
        .deleteTemporary(candidate.tempId);
    ref.invalidate(interruptedLocalRecordingProvider);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }
}

class _InterruptedBody extends StatelessWidget {
  const _InterruptedBody({
    required this.candidate,
    required this.platform,
    required this.onRecover,
    required this.onLater,
    this.errorMessage,
  });

  final LocalRecoveryCandidate candidate;
  final DevicePlatform platform;
  final VoidCallback onRecover;
  final VoidCallback onLater;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final String interruptionBody = platform == DevicePlatform.android
        ? context.l10n.localRecoveryInterruptedAndroidBody(
            _formatTime(context, candidate.interruptedAt),
          )
        : context.l10n.localRecoveryInterruptedIosBody(
            _formatTime(context, candidate.interruptedAt),
          );

    return _RecoveryFrame(
      children: <Widget>[
        const Icon(Icons.report_problem_outlined, size: 56),
        const SizedBox(height: SsSpacing.md),
        Text(
          context.l10n.localRecoveryInterruptedTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SsSpacing.md),
        Text(interruptionBody),
        const SizedBox(height: SsSpacing.lg),
        _CandidateCard(candidate: candidate),
        const SizedBox(height: SsSpacing.md),
        SsInlineAlert(
          title: context.l10n.localRecoveryOfflineTitle,
          message: context.l10n.localRecoveryOfflineBody,
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: context.l10n.localRecordingErrorTitle,
            message: errorMessage,
            tone: SsInlineAlertTone.error,
          ),
        ],
        const SizedBox(height: SsSpacing.lg),
        SsPrimaryButton(
          label: context.l10n.localRecoveryRecoverAction,
          icon: Icons.restore_rounded,
          onPressed: onRecover,
        ),
        const SizedBox(height: SsSpacing.sm),
        SsSecondaryButton(
          label: context.l10n.laterAction,
          onPressed: onLater,
        ),
      ],
    );
  }
}

class _RecoveringBody extends ConsumerWidget {
  const _RecoveringBody({required this.candidate});

  final LocalRecoveryCandidate candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocalRecoveryStep current =
        ref.watch(localRecoveryProgressProvider).value?.step ??
        LocalRecoveryStep.findTemporaryFile;
    final List<String> labels = <String>[
      context.l10n.localRecoveryFindStep,
      context.l10n.localRecoveryRepairStep,
      context.l10n.localRecoveryVerifyStep,
      context.l10n.localRecoveryRegisterStep,
    ];

    return _RecoveryFrame(
      children: <Widget>[
        Text(
          context.l10n.localRecoveryRecoveringTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SsSpacing.lg),
        SsChecklist(
          items: <SsChecklistItem>[
            for (int index = 0; index < labels.length; index += 1)
              SsChecklistItem(
                label: labels[index],
                done: index < current.index,
                active: index == current.index,
              ),
          ],
        ),
        const SizedBox(height: SsSpacing.lg),
        SsInlineAlert(
          title: context.l10n.localRecoveryOfflineTitle,
          message: context.l10n.localRecoveryRecoveringBody,
        ),
        const SizedBox(height: SsSpacing.md),
        _CandidateCard(candidate: candidate),
      ],
    );
  }
}

class _RecoveryResultBody extends StatelessWidget {
  const _RecoveryResultBody({
    required this.result,
    required this.platform,
    required this.onDeleteTemporary,
  });

  final LocalRecoveryResult result;
  final DevicePlatform platform;
  final VoidCallback onDeleteTemporary;

  @override
  Widget build(BuildContext context) {
    if (result.outcome == LocalRecoveryOutcome.failed) {
      return _RecoveryFailedBody(
        result: result,
        platform: platform,
        onDeleteTemporary: onDeleteTemporary,
      );
    }

    final bool partial = result.outcome == LocalRecoveryOutcome.partial;
    return _RecoveryFrame(
      children: <Widget>[
        Icon(
          partial ? Icons.contrast_rounded : Icons.check_circle_rounded,
          size: 56,
        ),
        const SizedBox(height: SsSpacing.md),
        Text(
          partial
              ? context.l10n.localRecoveryPartialTitle
              : context.l10n.localRecoveryRecoveredTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SsSpacing.lg),
        SsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                result.candidate.creatorDisplayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(result.candidate.creatorHandle),
              const SizedBox(height: SsSpacing.sm),
              Text(
                context.l10n.localRecoveryKeptDuration(
                  formatDurationHms(
                    Duration(seconds: result.recordedSeconds),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SsSpacing.md),
        _PlatformRecoveryAdvice(platform: platform),
        const SizedBox(height: SsSpacing.lg),
        if (result.recordingId != null)
          SsPrimaryButton(
            label: context.l10n.localRecordingOpenAction,
            icon: Icons.play_circle_outline_rounded,
            onPressed: () => context.push(
              AppRoutes.recordingDetail(result.recordingId!),
            ),
          ),
        const SizedBox(height: SsSpacing.sm),
        SsSecondaryButton(
          label: context.l10n.localRecordingHomeAction,
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
    );
  }
}

class _RecoveryFailedBody extends StatelessWidget {
  const _RecoveryFailedBody({
    required this.result,
    required this.platform,
    required this.onDeleteTemporary,
  });

  final LocalRecoveryResult result;
  final DevicePlatform platform;
  final VoidCallback onDeleteTemporary;

  @override
  Widget build(BuildContext context) {
    return _RecoveryFrame(
      children: <Widget>[
        const Icon(Icons.error_outline_rounded, size: 56),
        const SizedBox(height: SsSpacing.md),
        Text(
          context.l10n.localRecoveryFailedTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SsSpacing.md),
        Text(
          platform == DevicePlatform.android
              ? context.l10n.localRecoveryFailedAndroidBody
              : context.l10n.localRecoveryFailedIosBody,
        ),
        const SizedBox(height: SsSpacing.lg),
        _CandidateCard(candidate: result.candidate),
        const SizedBox(height: SsSpacing.md),
        _PlatformRecoveryAdvice(platform: platform),
        const SizedBox(height: SsSpacing.lg),
        SsPrimaryButton(
          label: context.l10n.localRecoveryDeleteTempAction,
          icon: Icons.delete_outline_rounded,
          onPressed: onDeleteTemporary,
        ),
        const SizedBox(height: SsSpacing.sm),
        SsSecondaryButton(
          label: context.l10n.localRecordingHomeAction,
          onPressed: () => context.go(AppRoutes.home),
        ),
      ],
    );
  }
}

class _PlatformRecoveryAdvice extends StatelessWidget {
  const _PlatformRecoveryAdvice({required this.platform});

  final DevicePlatform platform;

  @override
  Widget build(BuildContext context) {
    if (platform == DevicePlatform.android) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsInlineAlert(
            title: context.l10n.localRecoveryAndroidAdviceTitle,
            message: context.l10n.localRecoveryAndroidAdviceBody,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SsTextAction(
              label: context.l10n.localRecoveryAndroidGuideAction,
              icon: Icons.battery_saver_outlined,
              onPressed: () => context.push(
                AppRoutes.onboardingAndroidPermission,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsInlineAlert(
          title: context.l10n.localRecoveryIosAdviceTitle,
          message: context.l10n.localRecoveryIosAdviceBody,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: SsTextAction(
            label: context.l10n.localRecoveryViewProAction,
            icon: Icons.cloud_outlined,
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ),
      ],
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate});

  final LocalRecoveryCandidate candidate;

  @override
  Widget build(BuildContext context) {
    return SsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            candidate.creatorDisplayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(candidate.creatorHandle),
          const SizedBox(height: SsSpacing.sm),
          Text(
            context.l10n.localRecoveryCandidateMeta(
              _formatTime(context, candidate.startedAt),
              formatDurationHms(
                Duration(seconds: candidate.recordedSeconds),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRecoveryBody extends StatelessWidget {
  const _NoRecoveryBody({required this.onHome});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SsEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: context.l10n.localRecoveryNoneTitle,
        message: context.l10n.localRecoveryNoneBody,
        action: SsPrimaryButton(
          label: context.l10n.localRecordingHomeAction,
          onPressed: onHome,
        ),
      ),
    );
  }
}

class _RecoveryFrame extends StatelessWidget {
  const _RecoveryFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatTime(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value.toLocal()),
  );
}
