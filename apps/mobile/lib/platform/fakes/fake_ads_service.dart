import 'package:flutter/widgets.dart';

import '../contracts/ads_service.dart';

/// Ads stand-in for mock builds and tests: nothing loads from Google.
final class FakeAdsService implements AdsService {
  FakeAdsService({
    this.rewardedConfigured = true,
    this.bannerConfigured = false,
    this.consent = true,
    this.outcome = RewardedAdOutcome.earned,
    this.privacyRequired = false,
  });

  @override
  final bool rewardedConfigured;

  @override
  final bool bannerConfigured;

  bool consent;
  RewardedAdOutcome outcome;
  bool privacyRequired;

  int consentChecks = 0;
  int privacyFormsShown = 0;
  final List<({String userId, String customData, bool personalized})> shown =
      <({String userId, String customData, bool personalized})>[];

  @override
  Future<bool> ensureConsent() async {
    consentChecks += 1;
    return consent;
  }

  @override
  Future<bool> privacyOptionsRequired() async => privacyRequired;

  @override
  Future<void> showPrivacyOptions() async {
    privacyFormsShown += 1;
  }

  @override
  Future<RewardedAdOutcome> showRewarded({
    required String userId,
    required String customData,
    required bool personalized,
  }) async {
    shown.add((
      userId: userId,
      customData: customData,
      personalized: personalized,
    ));
    return outcome;
  }

  @override
  Widget buildBanner({required bool personalized}) {
    return const SizedBox(key: ValueKey<String>('fake-ad-banner'), height: 50);
  }
}
