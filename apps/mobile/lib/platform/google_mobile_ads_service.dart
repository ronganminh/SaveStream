import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'contracts/ads_service.dart';

/// Ad unit ids. Production ids come from the build, never from sources:
///   --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-…/…
///   --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-…/…
/// (the Android release workflow passes them; the AdMob app id is the
/// manifest placeholder from SAVESTREAM_ADMOB_ANDROID_APP_ID). Debug and
/// profile builds without them use Google's public test units; a release
/// build without them shows no ads.
final class AdMobConfig {
  const AdMobConfig({this.rewardedUnitId, this.bannerUnitId});

  factory AdMobConfig.fromEnvironment({
    bool isAndroid = false,
    bool useTestFallback = !kReleaseMode,
  }) {
    if (!isAndroid) return const AdMobConfig();
    const String rewarded = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
    const String banner = String.fromEnvironment('ADMOB_BANNER_ANDROID');
    String? pick(String configured, String testId) {
      if (configured.trim().isNotEmpty) return configured.trim();
      return useTestFallback ? testId : null;
    }

    return AdMobConfig(
      rewardedUnitId: pick(rewarded, androidTestRewardedUnitId),
      bannerUnitId: pick(banner, androidTestBannerUnitId),
    );
  }

  /// Google's public sample units (never billed).
  static const String androidTestRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String androidTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  final String? rewardedUnitId;
  final String? bannerUnitId;
}

final class GoogleMobileAdsService implements AdsService {
  GoogleMobileAdsService({AdMobConfig? config})
    : _config =
          config ?? AdMobConfig.fromEnvironment(isAndroid: Platform.isAndroid);

  final AdMobConfig _config;
  Future<bool>? _consent;
  bool _started = false;

  @override
  bool get rewardedConfigured => _config.rewardedUnitId != null;

  @override
  bool get bannerConfigured => _config.bannerUnitId != null;

  @override
  Future<bool> ensureConsent() {
    // One consent round per app run; a failed one may be retried.
    return _consent ??= _gatherConsent().then((bool allowed) {
      if (!allowed) _consent = null;
      return allowed;
    });
  }

  Future<bool> _gatherConsent() async {
    final Completer<void> updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      updated.complete,
      (FormError error) => updated.complete(),
    );
    await updated.future;
    final Completer<void> shown = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) => shown.complete(),
    );
    await shown.future;
    final bool allowed = await ConsentInformation.instance.canRequestAds();
    if (allowed && !_started) {
      _started = true;
      await MobileAds.instance.initialize();
    }
    return allowed;
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() async {
    final Completer<void> done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  }

  @override
  Future<RewardedAdOutcome> showRewarded({
    required String userId,
    required String customData,
    required bool personalized,
  }) async {
    final String? unitId = _config.rewardedUnitId;
    if (unitId == null || !await ensureConsent()) {
      return RewardedAdOutcome.failedToLoad;
    }
    final Completer<RewardedAdOutcome> result = Completer<RewardedAdOutcome>();
    void finish(RewardedAdOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    await RewardedAd.load(
      adUnitId: unitId,
      request: AdRequest(nonPersonalizedAds: !personalized),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) async {
          bool earned = false;
          // AdMob forwards these to the SSV callback as user_id and
          // custom_data; the backend matches them to the reward intent.
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(
              userId: userId,
              customData: customData,
            ),
          );
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdDismissedFullScreenContent: (RewardedAd dismissed) {
              dismissed.dispose();
              finish(
                earned ? RewardedAdOutcome.earned : RewardedAdOutcome.dismissed,
              );
            },
            onAdFailedToShowFullScreenContent:
                (RewardedAd failed, AdError error) {
                  failed.dispose();
                  finish(RewardedAdOutcome.failedToShow);
                },
          );
          try {
            await ad.show(
              onUserEarnedReward: (AdWithoutView _, RewardItem _) {
                earned = true;
              },
            );
          } on Object {
            ad.dispose();
            finish(RewardedAdOutcome.failedToShow);
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          finish(RewardedAdOutcome.failedToLoad);
        },
      ),
    );
    return result.future;
  }

  @override
  Widget buildBanner({required bool personalized}) {
    final String? unitId = _config.bannerUnitId;
    if (unitId == null) return const SizedBox.shrink();
    return _BannerSlot(
      unitId: unitId,
      personalized: personalized,
      ensureConsent: ensureConsent,
    );
  }
}

/// One 320×50 banner; takes no space until an ad has loaded.
class _BannerSlot extends StatefulWidget {
  const _BannerSlot({
    required this.unitId,
    required this.personalized,
    required this.ensureConsent,
  });

  final String unitId;
  final bool personalized;
  final Future<bool> Function() ensureConsent;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!await widget.ensureConsent() || !mounted) return;
    final BannerAd ad = BannerAd(
      adUnitId: widget.unitId,
      size: AdSize.banner,
      request: AdRequest(nonPersonalizedAds: !widget.personalized),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
