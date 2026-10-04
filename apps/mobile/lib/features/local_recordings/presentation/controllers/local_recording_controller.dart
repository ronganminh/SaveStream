import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../../../platform/contracts/local_recorder.dart';
import '../../../../platform/platform_providers.dart';
import '../../../channels/domain/models/watch_summary.dart';
import '../../../recordings/domain/models/recording_summary.dart';
import '../../data/repositories/mock_local_recording_repository.dart';
import '../../domain/models/local_recording_models.dart';
import '../../domain/repositories/local_recording_repository.dart';

final Provider<LocalRecordingRepository> localRecordingRepositoryProvider =
    Provider<LocalRecordingRepository>(
      (ref) => MockLocalRecordingRepository(ref.watch(mockBehaviorProvider)),
    );

final StreamProvider<LocalRecorderState> localRecorderStateProvider =
    StreamProvider<LocalRecorderState>(
      (ref) => ref.watch(localRecorderProvider).watch(),
    );

enum LocalRecordingFlowPhase {
  idle,
  starting,
  recording,
  reconnecting,
  finalizing,
  completed,
  error,
}

class LocalRecordingFlowState {
  const LocalRecordingFlowState({
    required this.phase,
    this.watchId,
    this.creatorDisplayName,
    this.creatorUsername,
    this.session,
    this.completed,
    this.recorderState = const LocalRecorderState(
      phase: LocalRecorderPhase.idle,
    ),
    this.extensionCount = 0,
    this.errorMessage,
  });

  const LocalRecordingFlowState.idle()
    : this(phase: LocalRecordingFlowPhase.idle);

  final LocalRecordingFlowPhase phase;
  final String? watchId;
  final String? creatorDisplayName;
  final String? creatorUsername;
  final LocalRecordingSession? session;
  final LocalRecordingSummary? completed;
  final LocalRecorderState recorderState;
  final int extensionCount;
  final String? errorMessage;

  bool get isActive {
    return switch (phase) {
      LocalRecordingFlowPhase.starting ||
      LocalRecordingFlowPhase.recording ||
      LocalRecordingFlowPhase.reconnecting ||
      LocalRecordingFlowPhase.finalizing => true,
      LocalRecordingFlowPhase.idle ||
      LocalRecordingFlowPhase.completed ||
      LocalRecordingFlowPhase.error => false,
    };
  }

  int get remainingSeconds {
    final LocalRecordingSession? current = session;
    if (current == null) return 0;
    final int remaining =
        current.grantedSeconds - recorderState.recordedSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  LocalRecordingFlowState copyWith({
    LocalRecordingFlowPhase? phase,
    String? watchId,
    String? creatorDisplayName,
    String? creatorUsername,
    LocalRecordingSession? session,
    bool clearSession = false,
    LocalRecordingSummary? completed,
    bool clearCompleted = false,
    LocalRecorderState? recorderState,
    int? extensionCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocalRecordingFlowState(
      phase: phase ?? this.phase,
      watchId: watchId ?? this.watchId,
      creatorDisplayName: creatorDisplayName ?? this.creatorDisplayName,
      creatorUsername: creatorUsername ?? this.creatorUsername,
      session: clearSession ? null : session ?? this.session,
      completed: clearCompleted ? null : completed ?? this.completed,
      recorderState: recorderState ?? this.recorderState,
      extensionCount: extensionCount ?? this.extensionCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final NotifierProvider<LocalRecordingController, LocalRecordingFlowState>
localRecordingControllerProvider =
    NotifierProvider<LocalRecordingController, LocalRecordingFlowState>(
      LocalRecordingController.new,
    );

class LocalRecordingController extends Notifier<LocalRecordingFlowState> {
  @override
  LocalRecordingFlowState build() {
    ref.listen<AsyncValue<LocalRecorderState>>(
      localRecorderStateProvider,
      (AsyncValue<LocalRecorderState>? previous,
       AsyncValue<LocalRecorderState> next) {
        next.whenData(_applyRecorderState);
      },
    );
    return const LocalRecordingFlowState.idle();
  }

  Future<void> start(WatchSummary watch) async {
    if (state.isActive) {
      throw StateError('A local recording is already active.');
    }

    state = LocalRecordingFlowState(
      phase: LocalRecordingFlowPhase.starting,
      watchId: watch.id,
      creatorDisplayName: watch.creatorDisplayName,
      creatorUsername: watch.creatorUsername,
    );

    try {
      final String deviceId =
          await ref.read(deviceInfoServiceProvider).deviceId;
      final LocalRecordingSession session = await ref
          .read(localRecordingRepositoryProvider)
          .start(watchId: watch.id, deviceId: deviceId);

      state = state.copyWith(session: session, clearError: true);
      await ref.read(localRecorderProvider).start(session);
    } on Object catch (error) {
      state = state.copyWith(
        phase: LocalRecordingFlowPhase.error,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> stop() async {
    final LocalRecordingSession? session = state.session;
    if (session == null || !state.isActive) return;

    state = state.copyWith(phase: LocalRecordingFlowPhase.finalizing);

    try {
      await ref.read(localRecorderProvider).stop();
      final LocalRecorderState recorderState = state.recorderState;
      final LocalRecordingSummary completed = await ref
          .read(localRecordingRepositoryProvider)
          .finish(
            session.sessionId,
            recordedSeconds: recorderState.recordedSeconds,
            sizeBytes: recorderState.sizeBytes,
            endReason: RecordingEndReason.userStopped,
            status: RecordingStatus.completed,
          );

      state = state.copyWith(
        phase: LocalRecordingFlowPhase.completed,
        completed: completed,
        clearSession: true,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        phase: LocalRecordingFlowPhase.error,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  void reset() {
    if (state.isActive) return;
    state = const LocalRecordingFlowState.idle();
  }

  void _applyRecorderState(LocalRecorderState recorderState) {
    if (state.watchId == null) return;

    final LocalRecordingFlowPhase nextPhase = switch (recorderState.phase) {
      LocalRecorderPhase.idle => state.phase,
      LocalRecorderPhase.starting => LocalRecordingFlowPhase.starting,
      LocalRecorderPhase.recording => LocalRecordingFlowPhase.recording,
      LocalRecorderPhase.reconnecting => LocalRecordingFlowPhase.reconnecting,
      LocalRecorderPhase.finalizing => LocalRecordingFlowPhase.finalizing,
      LocalRecorderPhase.stopped => state.phase,
      LocalRecorderPhase.error => LocalRecordingFlowPhase.error,
    };

    state = state.copyWith(
      phase: nextPhase,
      recorderState: recorderState,
      errorMessage: recorderState.errorMessage,
      clearError: recorderState.errorMessage == null,
    );
  }
}
