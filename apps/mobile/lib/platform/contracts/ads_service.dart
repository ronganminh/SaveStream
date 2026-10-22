import 'package:flutter/widgets.dart';

/// How a rewarded ad ended, from the device's point of view. Minutes are
/// only added when AdMob's server-side verification reaches the backend.
enum RewardedAdOutcome {
  /// The user watched to the end (the SDK fired onUserEarnedReward).
  earned,

  /// Closed before the reward.
  dismissed,

  /// No ad to show (no fill, network, or the SDK refused to load).
  failedToLoad,

  /// Loaded but could not be shown.
  failedToShow,
}

/// Google Mobile Ads with the User Messaging Platform consent flow.
abstract interface class AdsService {
  /// A rewarded ad unit is configured for this build and platform.
  bool get rewardedConfigured;

  /// A banner ad unit is configured for this build and platform.
  bool get bannerConfigured;

  /// Refreshes UMP consent info, shows the consent form when it is required
  /// (EEA, UK, Switzerland) and not answered yet, then starts the SDK.
  /// Returns whether ads may be requested.
  Future<bool> ensureConsent();

  /// The UMP privacy options entry point is required (consent was asked).
  Future<bool> privacyOptionsRequired();

  /// Opens the UMP privacy options form so the user can change consent.
  Future<void> showPrivacyOptions();

  /// Loads and shows one rewarded ad with AdMob server-side verification:
  /// [userId] and [customData] come from `POST /v1/rewards`.
  Future<RewardedAdOutcome> showRewarded({
    required String userId,
    required String customData,
    required bool personalized,
  });

  /// A widget that loads one adaptive banner (or nothing when it can't).
  Widget buildBanner({required bool personalized});
}
