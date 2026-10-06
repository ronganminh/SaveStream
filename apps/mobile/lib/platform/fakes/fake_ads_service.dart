import 'package:flutter/widgets.dart';

import '../../features/rewards/domain/models/reward.dart';
import '../contracts/ads_service.dart';

final class FakeAdsService implements AdsService {
  const FakeAdsService({
    this.consentState = AdConsentState.granted,
    this.rewardResult = true,
  });

  @override
  final AdConsentState consentState;

  final bool rewardResult;

  @override
  Stream<AdConsentState> get consentStates =>
      Stream<AdConsentState>.value(consentState);

  @override
  Future<void> requestConsent() async {}

  @override
  Widget? bannerFor(AdPlacement placement) => null;

  @override
  Future<bool> showRewarded(Reward reward) async => rewardResult;
}
