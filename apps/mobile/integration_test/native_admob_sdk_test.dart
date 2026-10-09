// Optional network-dependent check: native AdMob SDK loads Google's official
// TEST inventory on Android/iOS. Never show an ad or use live ad unit IDs.
// PR CI records this separately and does not block merges on test-ad no-fill.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('Google Mobile Ads native plugin initializes on this OS', () async {
    await MobileAds.instance.initialize().timeout(const Duration(seconds: 25));
  });

  test('Google TEST banner can be loaded by native AdMob SDK', () async {
    final Completer<bool> result = Completer<bool>();
    late BannerAd banner;
    banner = BannerAd(
      adUnitId: Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2435281174'
          : 'ca-app-pub-3940256099942544/9214589741',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => result.complete(true),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (!result.isCompleted) {
            result.completeError(StateError('Google test banner: $error'));
          }
        },
      ),
    );
    try {
      await banner.load();
      expect(await result.future.timeout(const Duration(seconds: 35)), isTrue);
    } finally {
      await banner.dispose();
    }
  });

  test('Google TEST rewarded loads with SSV parameters', () async {
    final Completer<RewardedAd> ad = Completer<RewardedAd>();
    RewardedAd.load(
      adUnitId: Platform.isIOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: ad.complete,
        onAdFailedToLoad: (LoadAdError error) {
          ad.completeError(StateError('Google test rewarded: $error'));
        },
      ),
    );
    final RewardedAd loaded = await ad.future.timeout(
      const Duration(seconds: 35),
    );
    try {
      await loaded.setServerSideOptions(
        ServerSideVerificationOptions(
          userId: 'ci-nonproduction-user',
          customData: 'ci-nonproduction-reward',
        ),
      );
      // DO NOT show the ad here: automated impressions/reward signals are
      // forbidden outside an explicitly authorized Google test-device flow.
    } finally {
      await loaded.dispose();
    }
  });
}
