import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../platform/contracts/ads_service.dart';
import '../../../../platform/platform_providers.dart';
import '../../../entitlement/domain/models/entitlement.dart';
import '../../../rewards/domain/models/reward.dart';
import 'local_recording_controller.dart';

enum RewardedMinutesPhase {
  idle,
  loadingAd,
  verifying,
  pending,
  success,
  noFill,
  invalid,
  locked,
  maxExtensions,
  dailyCap,
  error,
}

class RewardedMinutesState {
  const RewardedMinutesState({
    this.phase = RewardedMinutesPhase.idle,
    this.rewardId,
    this.extensionCount = 0,
    this.errorMessage,
  });

  final RewardedMinutesPhase phase;
  final String? rewardId;
  final int extensionCount;
  final String? errorMessage;

  RewardedMinutesState copyWith({
    RewardedMinutesPhase? phase,
    String? rewardId,
    int? extensionCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RewardedMinutesState(
      phase: phase ?? this.phase,
      rewardId: rewardId ?? this.rewardId,
      extensionCount: extensionCount ?? this.extensionCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final Provider<Duration> rewardVerificationTimeoutProvider = Provider<Duration>(
  (Ref ref) => const Duration(seconds: 15),
);

final Provider<Duration> rewardVerificationPollIntervalProvider =
    Provider<Duration>((Ref ref) => const Duration(seconds: 2));

final NotifierProvider<RewardedMinutesController, RewardedMinutesState>
rewardedMinutesControllerProvider =
    NotifierProvider<RewardedMinutesController, RewardedMinutesState>(
      RewardedMinutesController.new,
    );

class RewardedMinutesController extends Notifier<RewardedMinutesState> {
  @override
  RewardedMinutesState build() => const RewardedMinutesState();

  Future<void> start({
    required LocalEntitlement entitlement,
    required int extensionsUsed,
  }) async {
    if (extensionsUsed >= entitlement.extensionsCapPerRecording) {
      state = state.copyWith(
        phase: RewardedMinutesPhase.maxExtensions,
        extensionCount: extensionsUsed,
        clearError: true,
      );
      return;
    }
    if (entitlement.rewardsUsedToday >= entitlement.rewardsCapPerDay) {
      state = state.copyWith(
        phase: RewardedMinutesPhase.dailyCap,
        extensionCount: extensionsUsed,
        clearError: true,
      );
      return;
    }

    final LocalRecordingController recording = ref.read(
      localRecordingControllerProvider,
    );
    final session = recording.activeSession;
    if (session == null) {
      state = state.copyWith(
        phase: RewardedMinutesPhase.error,
        errorMessage: 'No active local recording session.',
      );
      return;
    }

    try {
      state = state.copyWith(
        phase: RewardedMinutesPhase.loadingAd,
        extensionCount: extensionsUsed,
        clearError: true,
      );

      final Reward reward = await ref
          .read(rewardRepositoryProvider)
          .create(
            purpose: RewardPurpose.localMinutes,
            sessionId: session.sessionId,
          );

      final AdsService ads = ref.read(adsServiceProvider);
      final bool watched = await ads.showRewarded(reward);
      if (!watched) {
        state = state.copyWith(
          phase: RewardedMinutesPhase.noFill,
          rewardId: reward.rewardId,
        );
        return;
      }

      state = state.copyWith(
        phase: RewardedMinutesPhase.verifying,
        rewardId: reward.rewardId,
      );
      await _verifyReward(
        rewardId: reward.rewardId,
        extensionCount: extensionsUsed,
        recording: recording,
      );
    } on ApiException catch (error) {
      _applyApiException(error, extensionCount: extensionsUsed);
    } on Object catch (error) {
      state = state.copyWith(
        phase: RewardedMinutesPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  void _applyApiException(
    ApiException error, {
    required int extensionCount,
  }) {
    final RewardedMinutesPhase phase = switch (error.code) {
      'REWARD_LOCKED' => RewardedMinutesPhase.locked,
      'REWARD_DAILY_CAP_REACHED' => RewardedMinutesPhase.dailyCap,
      'EXTENSION_LIMIT_REACHED' => RewardedMinutesPhase.maxExtensions,
      _ => RewardedMinutesPhase.error,
    };
    state = state.copyWith(
      phase: phase,
      extensionCount: extensionCount,
      errorMessage:
          phase == RewardedMinutesPhase.error ? error.message : null,
      clearError: phase != RewardedMinutesPhase.error,
    );
  }

  void reset() {
    state = const RewardedMinutesState();
  }

  Future<void> _verifyReward({
    required String rewardId,
    required int extensionCount,
    required LocalRecordingController recording,
  }) async {
    final Duration timeout = ref.read(rewardVerificationTimeoutProvider);
    final Duration interval = ref.read(rewardVerificationPollIntervalProvider);
    final DateTime deadline = DateTime.now().add(timeout);

    while (true) {
      final Reward reward = await ref
          .read(rewardRepositoryProvider)
          .getStatus(rewardId);

      switch (reward.status) {
        case RewardStatus.valid:
          await recording.extendWithReward(reward.rewardId);
          state = state.copyWith(
            phase: RewardedMinutesPhase.success,
            rewardId: reward.rewardId,
            extensionCount: extensionCount + 1,
            clearError: true,
          );
          return;
        case RewardStatus.invalid:
        case RewardStatus.expired:
          state = state.copyWith(
            phase: RewardedMinutesPhase.invalid,
            rewardId: reward.rewardId,
          );
          return;
        case RewardStatus.pending:
          if (!DateTime.now().isBefore(deadline)) {
            state = state.copyWith(
              phase: RewardedMinutesPhase.pending,
              rewardId: reward.rewardId,
            );
            return;
          }
          await Future<void>.delayed(interval);
      }
    }
  }
}
