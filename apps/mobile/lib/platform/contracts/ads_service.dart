import 'package:flutter/widgets.dart';

import '../../features/rewards/domain/models/reward.dart';

enum AdConsentState { unknown, required, granted, denied }

enum AdPlacement { home, watchList, library }

abstract interface class AdsService {
  Future<bool> showRewarded(Reward reward);

  Widget? bannerFor(AdPlacement placement);

  AdConsentState get consentState;

  Stream<AdConsentState> get consentStates;

  Future<void> requestConsent();
}
