import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../l10n/l10n.dart';
import '../../../platform/contracts/local_recorder.dart';
import '../../../platform/contracts/recording_platform_service.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../../recordings/domain/models/recording_summary.dart';
import '../domain/models/local_recording_models.dart';
import 'controllers/local_recording_controller.dart';
import 'controllers/local_recovery_providers.dart';
import 'controllers/recording_platform_controller.dart';

class RecordingPlatformBridge extends ConsumerStatefulWidget {
  const RecordingPlatformBridge({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<RecordingPlatformBridge> createState() =>
      _RecordingPlatformBridgeState();
}

class _RecordingPlatformBridgeState
    extends ConsumerState<RecordingPlatformBridge>
    with WidgetsBindingObserver {
  String? _activeCreatorName;
  bool _activeRecording = false;
  String? _lastNotificationSignature;
  String? _lastInterruptedTempId;
  String? _lastLifecycleSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final String? creatorName = _activeCreatorName;
    if (creatorName == null && !_activeRecording) return;
    unawaited(
      ref
          .read(recordingPlatformControllerProvider)
          .handleIosLifecycle(
            state: state,
            creatorName: creatorName ?? '',
            activeRecording: _activeRecording,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(localRecordingControllerProvider);
    final LocalRecorderState? primaryState = ref
        .watch(localRecorderStateProvider)
        .value;
    final LocalRecorderState? secondaryState = ref
        .watch(secondaryLocalRecorderStateProvider)
        .value;
    final dashboard = ref.watch(homeDashboardProvider).value;
    final interrupted = ref.watch(interruptedLocalRecordingProvider).value;
    final entitlement = dashboard?.entitlement.local;

    final LocalRecordingSession? session =
        controller.activeSession ?? controller.secondarySession;
    final bool usingSecondary =
        controller.activeSession == null && controller.secondarySession != null;
    final LocalRecorderState? state = usingSecondary
        ? secondaryState
        : primaryState;

    String? creatorName;
    if (session != null && dashboard != null) {
      for (final watch in dashboard.watches) {
        if (watch.id == session.watchId) {
          creatorName = watch.creatorDisplayName;
          break;
        }
      }
    }

    final bool active = session != null && _isPlatformActive(state?.phase);
    _activeCreatorName = creatorName;
    _activeRecording = active;

    final String lifecycleSignature =
        '${creatorName ?? ''}:$active';
    if (_lastLifecycleSignature != lifecycleSignature) {
      _lastLifecycleSignature = lifecycleSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(recordingPlatformControllerProvider)
              .handleIosLifecycle(
                state:
                    WidgetsBinding.instance.lifecycleState ??
                    AppLifecycleState.resumed,
                creatorName: creatorName ?? '',
                activeRecording: active,
              ),
        );
      });
    }

    if (session != null &&
        state != null &&
        creatorName != null &&
        entitlement != null) {
      final int rawRemaining =
          session.grantedSeconds - state.recordedSeconds;
      final int remaining = rawRemaining > 0 ? rawRemaining : 0;
      final String signature =
          '${session.sessionId}:${state.phase.name}:'
          '${state.recordedSeconds}:$remaining:${entitlement.unlimited}';
      if (_lastNotificationSignature != signature) {
        _lastNotificationSignature = signature;
        final String activeCreator = creatorName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref
                .read(recordingPlatformControllerProvider)
                .syncAndroidNotification(
                  l10n: context.l10n,
                  creatorName: activeCreator,
                  state: state,
                  unlimited: entitlement.unlimited,
                  remainingSeconds: remaining,
                ),
          );
        });
      }
    }

    if (interrupted != null &&
        interrupted.tempId != _lastInterruptedTempId) {
      _lastInterruptedTempId = interrupted.tempId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(recordingPlatformControllerProvider)
              .showInterrupted(
                l10n: context.l10n,
                creatorName: interrupted.creatorDisplayName,
              ),
        );
      });
    }

    ref.listen<AsyncValue<RecordingPlatformAction>>(
      recordingPlatformActionProvider,
      (previous, next) {
        final RecordingPlatformAction? action = next.value;
        if (action == null) return;
        _handlePlatformAction(
          action,
          controller: controller,
          creatorName: creatorName,
          usingSecondary: usingSecondary,
        );
      },
    );

    return widget.child;
  }

  void _handlePlatformAction(
    RecordingPlatformAction action, {
    required LocalRecordingController controller,
    required String? creatorName,
    required bool usingSecondary,
  }) {
    switch (action) {
      case RecordingPlatformAction.stopRecording:
        if (controller.activeSession == null &&
            controller.secondarySession == null) {
          return;
        }
        unawaited(
          _stopFromPlatformAction(
            controller: controller,
            creatorName: creatorName ?? '',
            usingSecondary: usingSecondary,
          ),
        );
        return;
      case RecordingPlatformAction.openRecording:
        final LocalRecordingSession? session =
            controller.activeSession ?? controller.secondarySession;
        if (session != null && mounted) {
          context.push(AppRoutes.localRecording(session.watchId));
        }
        return;
      case RecordingPlatformAction.recoverInterrupted:
        if (mounted) {
          context.push(AppRoutes.localRecovery);
        }
        return;
    }
  }

  Future<void> _stopFromPlatformAction({
    required LocalRecordingController controller,
    required String creatorName,
    required bool usingSecondary,
  }) async {
    final LocalRecordingSummary summary = usingSecondary
        ? await controller.stopSecond(
            status: RecordingStatus.completed,
          )
        : await controller.stop(
            status: RecordingStatus.completed,
          );
    if (!mounted) return;
    await ref
        .read(recordingPlatformControllerProvider)
        .showCompleted(
          l10n: context.l10n,
          creatorName: creatorName,
          recordedSeconds: summary.recordedSeconds,
          sizeBytes: summary.sizeBytes,
          recordingId: summary.id,
        );
  }

  bool _isPlatformActive(LocalRecorderPhase? phase) {
    return phase == LocalRecorderPhase.starting ||
        phase == LocalRecorderPhase.recording ||
        phase == LocalRecorderPhase.reconnecting ||
        phase == LocalRecorderPhase.finalizing;
  }
}
