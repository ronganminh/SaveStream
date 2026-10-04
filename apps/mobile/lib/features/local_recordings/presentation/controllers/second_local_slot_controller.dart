import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../platform/contracts/ads_service.dart';
import '../../../../platform/platform_providers.dart';
import '../../../entitlement/domain/models/entitlement.dart';
import '../../../entitlement/presentation/entitlement_providers.dart';
import '../../../rewards/domain/models/reward.dart';
import 'local_recording_controller.dart';
import 'rewarded_minutes_controller.dart';

enum SecondLocalSlotPhase {
  idle,
  loadingAd,
  verifying,
  progress,
  pending,
  unlocked,
  noFill,
  invalid,
  locked,
  dailyCap,
  expired,
  error,
}

class SecondLocalSlotState {
  const SecondLocalSlotState({
    this.phase = SecondLocalSlotPhase.idle,
    this.verifiedRewards = 0,
    this.expiresAt,
    this.rewardId,
    this.errorMessage,
  });

  final SecondLocalSlotPhase phase;
  final int verifiedRewards;
  final DateTime? expiresAt;
  final String? rewardId;
  final String? errorMessage;

  SecondLocalSlotState copyWith({
    SecondLocalSlotPhase? phase,
    int? verifiedRewards,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    String? rewardId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SecondLocalSlotState(
      phase: phase ?? this.phase,
      verifiedRewards: verifiedRewards ?? this.verifiedRewards,
      expiresAt: clearExpiresAt ? null : expiresAt ?? this.expiresAt,
      rewardId: rewardId ?? this.rewardId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final NotifierProvider<SecondLocalSlotController, SecondLocalSlotState>
secondLocalSlotControllerProvider =
    NotifierProvider<SecondLocalSlotController, SecondLocalSlotState>(
      SecondLocalSlotController.new,
    );

class SecondLocalSlotController extends Notifier<SecondLocalSlotState> {
  static const int rewardsRequired = 2;

  @override
  SecondLocalSlotState build() => const SecondLocalSlotState();

  Future<void> start(LocalEntitlement entitlement) async {
    if (entitlement.rewardsUsedToday >= entitlement.rewardsCapPerDay) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.dailyCap,
        clearError: true,
      );
      return;
    }

    try {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.loadingAd,
        clearError: true,
      );
      final Reward reward = await ref
          .read(rewardRepositoryProvider)
          .create(purpose: RewardPurpose.localSlot);

      final AdsService ads = ref.read(adsServiceProvider);
      final bool watched = await ads.showRewarded(reward);
      if (!watched) {
        state = state.copyWith(
          phase: SecondLocalSlotPhase.noFill,
          rewardId: reward.rewardId,
        );
        return;
      }

      state = state.copyWith(
        phase: SecondLocalSlotPhase.verifying,
        rewardId: reward.rewardId,
      );
      await _verify(reward.rewardId);
    } on ApiException catch (error) {
      _applyApiException(error);
    } on Object catch (error) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.error,
        errorMessage: error.toString(),
      );
    }
  }

  void syncEntitlement(LocalEntitlement entitlement) {
    final DateTime? expiresAt = entitlement.secondSlotExpiresAt;
    if (entitlement.maxConcurrentSessions >= 2 &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now())) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.unlocked,
        verifiedRewards: rewardsRequired,
        expiresAt: expiresAt,
        clearError: true,
      );
      return;
    }
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.expired,
        expiresAt: expiresAt,
        clearError: true,
      );
    }
  }

  void resetTransientError() {
    if (state.phase == SecondLocalSlotPhase.error ||
        state.phase == SecondLocalSlotPhase.noFill ||
        state.phase == SecondLocalSlotPhase.invalid) {
      state = state.copyWith(
        phase: state.verifiedRewards > 0
            ? SecondLocalSlotPhase.progress
            : SecondLocalSlotPhase.idle,
        clearError: true,
      );
    }
  }

  Future<void> _verify(String rewardId) async {
    final Duration timeout = ref.read(rewardVerificationTimeoutProvider);
    final Duration interval = ref.read(rewardVerificationPollIntervalProvider);
    final DateTime deadline = DateTime.now().add(timeout);

    while (true) {
      final Reward reward = await ref
          .read(rewardRepositoryProvider)
          .getStatus(rewardId);
      switch (reward.status) {
        case RewardStatus.valid:
          await _acceptValidReward();
          return;
        case RewardStatus.invalid:
        case RewardStatus.expired:
          state = state.copyWith(
            phase: SecondLocalSlotPhase.invalid,
            rewardId: reward.rewardId,
          );
          return;
        case RewardStatus.pending:
          if (!DateTime.now().isBefore(deadline)) {
            state = state.copyWith(
              phase: SecondLocalSlotPhase.pending,
              rewardId: reward.rewardId,
            );
            return;
          }
          await Future<void>.delayed(interval);
      }
    }
  }

  Future<void> _acceptValidReward() async {
    final int verified = (state.verifiedRewards + 1).clamp(
      0,
      rewardsRequired,
    );
    if (verified < rewardsRequired) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.progress,
        verifiedRewards: verified,
        clearError: true,
      );
      return;
    }

    final Entitlement refreshed = await ref
        .read(entitlementRepositoryProvider)
        .getEntitlement();
    final DateTime? expiresAt = refreshed.local.secondSlotExpiresAt;
    if (refreshed.local.maxConcurrentSessions >= 2 &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now())) {
      state = state.copyWith(
        phase: SecondLocalSlotPhase.unlocked,
        verifiedRewards: verified,
        expiresAt: expiresAt,
        clearError: true,
      );
      ref.invalidate(entitlementProvider);
      return;
    }

    state = state.copyWith(
      phase: SecondLocalSlotPhase.pending,
      verifiedRewards: verified,
      clearError: true,
    );
  }

  void _applyApiException(ApiException error) {
    final SecondLocalSlotPhase phase = switch (error.code) {
      'REWARD_LOCKED' => SecondLocalSlotPhase.locked,
      'REWARD_DAILY_CAP_REACHED' => SecondLocalSlotPhase.dailyCap,
      _ => SecondLocalSlotPhase.error,
    };
    state = state.copyWith(
      phase: phase,
      errorMessage: phase == SecondLocalSlotPhase.error ? error.message : null,
      clearError: phase != SecondLocalSlotPhase.error,
    );
  }
}
