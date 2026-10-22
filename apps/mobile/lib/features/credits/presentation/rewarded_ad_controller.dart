import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../platform/contracts/ads_service.dart';
import '../../../platform/platform_providers.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/credit_ledger.dart';
import 'credits_providers.dart';

enum RewardPhase {
  idle,

  /// Creating the reward intent and loading the ad.
  loading,

  /// The ad was watched; waiting for AdMob's server-side verification.
  verifying,

  /// The server credited the minutes.
  earned,

  /// Verification is taking longer than the app waits; the minutes arrive
  /// when Google's callback does.
  slow,

  /// The server asked to wait before the next ad.
  cooldown,

  /// The daily cap is used up.
  limit,

  /// The ad did not load or show; nothing was used.
  failed,

  /// Rewards need a verified email.
  emailUnverified,

  /// Rewarded ads are switched off on the server (hide the card).
  unavailable,
}

class RewardState {
  const RewardState({this.phase = RewardPhase.idle, this.cooldownUntil});

  final RewardPhase phase;
  final DateTime? cooldownUntil;

  bool get busy =>
      phase == RewardPhase.loading || phase == RewardPhase.verifying;
}

/// How long the app polls `GET /v1/rewards/{id}` after the ad, and how often.
class RewardPolling {
  const RewardPolling({
    this.interval = const Duration(milliseconds: 1500),
    this.attempts = 20,
  });

  final Duration interval;
  final int attempts;
}

final Provider<RewardPolling> rewardPollingProvider = Provider<RewardPolling>(
  (ref) => const RewardPolling(),
);

/// Used when a 429 carries no time to wait until.
const Duration defaultRewardCooldown = Duration(minutes: 5);

final NotifierProvider<RewardedAdController, RewardState>
rewardedAdControllerProvider =
    NotifierProvider<RewardedAdController, RewardState>(
      RewardedAdController.new,
    );

/// "Watch ad · +5 min": POST /v1/rewards (cloud_minutes) → show the rewarded
/// ad with the intent's SSV user id and custom data → poll the intent until
/// AdMob's callback marked it valid → refresh entitlement and balance.
class RewardedAdController extends Notifier<RewardState> {
  @override
  RewardState build() => const RewardState();

  Future<void> watchAd() async {
    if (state.busy) return;
    state = const RewardState(phase: RewardPhase.loading);

    final RewardIntent intent;
    try {
      final String deviceId = await ref
          .read(deviceInfoServiceProvider)
          .deviceId;
      intent = await ref
          .read(rewardsRepositoryProvider)
          .createCloudMinutesReward(deviceId: deviceId);
    } on ApiException catch (error) {
      _onIntentError(error);
      return;
    } on Object {
      state = const RewardState(phase: RewardPhase.failed);
      return;
    }

    bool personalized;
    try {
      personalized = await ref.read(personalizedAdsProvider.future);
    } on Object {
      personalized = true;
    }
    final RewardedAdOutcome outcome = await ref
        .read(adsServiceProvider)
        .showRewarded(
          userId: intent.ssvUserId,
          customData: intent.ssvCustomData,
          personalized: personalized,
        );
    switch (outcome) {
      case RewardedAdOutcome.dismissed:
        state = const RewardState();
        return;
      case RewardedAdOutcome.failedToLoad:
      case RewardedAdOutcome.failedToShow:
        state = const RewardState(phase: RewardPhase.failed);
        return;
      case RewardedAdOutcome.earned:
        await _verify(intent.rewardId);
    }
  }

  /// Back to idle once the earned message was shown.
  void acknowledge() {
    if (state.phase == RewardPhase.earned || state.phase == RewardPhase.slow) {
      state = const RewardState();
    }
  }

  /// Ends a cooldown whose time has passed.
  void cooldownElapsed() {
    if (state.phase == RewardPhase.cooldown) state = const RewardState();
  }

  Future<void> _verify(String rewardId) async {
    state = const RewardState(phase: RewardPhase.verifying);
    final RewardPolling polling = ref.read(rewardPollingProvider);
    final RewardsRepository rewards = ref.read(rewardsRepositoryProvider);
    for (int attempt = 0; attempt < polling.attempts; attempt++) {
      RewardStatus status;
      try {
        status = await rewards.getRewardStatus(rewardId);
      } on Object {
        status = RewardStatus.pending;
      }
      switch (status) {
        case RewardStatus.valid:
          _refresh();
          state = const RewardState(phase: RewardPhase.earned);
          return;
        case RewardStatus.invalid:
        case RewardStatus.expired:
          _refresh();
          state = const RewardState(phase: RewardPhase.failed);
          return;
        case RewardStatus.pending:
          await Future<void>.delayed(polling.interval);
      }
    }
    _refresh();
    state = const RewardState(phase: RewardPhase.slow);
  }

  void _onIntentError(ApiException error) {
    switch (error.code) {
      case 'REWARDED_ADS_UNAVAILABLE':
      case 'SERVICE_UNAVAILABLE':
      case 'REWARD_PURPOSE_RETIRED':
        state = const RewardState(phase: RewardPhase.unavailable);
      case 'REWARD_DAILY_CAP_REACHED':
        ref.invalidate(entitlementProvider);
        state = const RewardState(phase: RewardPhase.limit);
      case 'EMAIL_NOT_VERIFIED':
        state = const RewardState(phase: RewardPhase.emailUnverified);
      case 'RATE_LIMITED':
      case 'REWARD_LOCKED':
        final Object? until = error.apiError?.details['locked_until'];
        final Object? after = error.apiError?.details['retry_after_seconds'];
        final DateTime now = ref.read(creditsClockProvider)();
        // retry_after_seconds is the server's real window (both codes);
        // locked_until and the 5-minute default cover older servers.
        DateTime cooldownUntil = now.add(defaultRewardCooldown);
        if (after is int && after > 0) {
          cooldownUntil = now.add(Duration(seconds: after));
        } else if (until is String && DateTime.tryParse(until) != null) {
          cooldownUntil = DateTime.parse(until).toLocal();
        }
        state = RewardState(
          phase: RewardPhase.cooldown,
          cooldownUntil: cooldownUntil,
        );
      default:
        state = const RewardState(phase: RewardPhase.failed);
    }
  }

  void _refresh() {
    ref.invalidate(entitlementProvider);
    ref.invalidate(creditBalanceProvider);
    ref.invalidate(creditTransactionsProvider);
    ref.invalidate(homeDashboardProvider);
  }
}
