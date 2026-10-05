import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../features/rewards/domain/models/reward.dart';
import 'contracts/ads_service.dart';

final class GoogleAdsConfig {
  const GoogleAdsConfig({
    required this.bannerHomeId,
    required this.bannerWatchListId,
    required this.bannerLibraryId,
    required this.rewardedId,
  });

  factory GoogleAdsConfig.forPlatform(TargetPlatform platform) {
    final bool ios = platform == TargetPlatform.iOS;
    return GoogleAdsConfig(
      bannerHomeId: ios
          ? const String.fromEnvironment(
              'ADMOB_BANNER_HOME_IOS',
              defaultValue: 'ca-app-pub-3940256099942544/2435281174',
            )
          : const String.fromEnvironment(
              'ADMOB_BANNER_HOME_ANDROID',
              defaultValue: 'ca-app-pub-3940256099942544/9214589741',
            ),
      bannerWatchListId: ios
          ? const String.fromEnvironment(
              'ADMOB_BANNER_WATCH_IOS',
              defaultValue: 'ca-app-pub-3940256099942544/2435281174',
            )
          : const String.fromEnvironment(
              'ADMOB_BANNER_WATCH_ANDROID',
              defaultValue: 'ca-app-pub-3940256099942544/9214589741',
            ),
      bannerLibraryId: ios
          ? const String.fromEnvironment(
              'ADMOB_BANNER_LIBRARY_IOS',
              defaultValue: 'ca-app-pub-3940256099942544/2435281174',
            )
          : const String.fromEnvironment(
              'ADMOB_BANNER_LIBRARY_ANDROID',
              defaultValue: 'ca-app-pub-3940256099942544/9214589741',
            ),
      rewardedId: ios
          ? const String.fromEnvironment(
              'ADMOB_REWARDED_IOS',
              defaultValue: 'ca-app-pub-3940256099942544/1712485313',
            )
          : const String.fromEnvironment(
              'ADMOB_REWARDED_ANDROID',
              defaultValue: 'ca-app-pub-3940256099942544/5224354917',
            ),
    );
  }

  final String bannerHomeId;
  final String bannerWatchListId;
  final String bannerLibraryId;
  final String rewardedId;

  String bannerId(AdPlacement placement) => switch (placement) {
    AdPlacement.home => bannerHomeId,
    AdPlacement.watchList => bannerWatchListId,
    AdPlacement.library => bannerLibraryId,
  };
}

abstract interface class MobileAdsRuntime {
  Future<AdConsentState> refreshConsentInfo();

  Future<AdConsentState> gatherConsentIfRequired();

  Future<bool> canRequestAds();

  Future<void> initialize();

  Future<bool> showRewarded({
    required String adUnitId,
    required String userId,
    required String customData,
  });
}

final class GoogleMobileAdsRuntime implements MobileAdsRuntime {
  const GoogleMobileAdsRuntime();

  @override
  Future<AdConsentState> refreshConsentInfo() async {
    final Completer<void> completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(),
      (FormError error) => completer.completeError(
        StateError('UMP consent update failed: ${error.message}'),
      ),
    );
    await completer.future;
    return _mapConsent(await ConsentInformation.instance.getConsentStatus());
  }

  @override
  Future<AdConsentState> gatherConsentIfRequired() async {
    final Completer<FormError?> completer = Completer<FormError?>();
    await ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) => completer.complete(error),
    );
    final FormError? error = await completer.future;
    final bool allowed = await ConsentInformation.instance.canRequestAds();
    if (error != null && !allowed) {
      return AdConsentState.denied;
    }
    final AdConsentState state = _mapConsent(
      await ConsentInformation.instance.getConsentStatus(),
    );
    return allowed && state == AdConsentState.required
        ? AdConsentState.granted
        : state;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<bool> showRewarded({
    required String adUnitId,
    required String userId,
    required String customData,
  }) {
    final Completer<bool> result = Completer<bool>();
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) async {
          bool earned = false;
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(
              userId: userId,
              customData: customData,
            ),
          );
          ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
            onAdDismissedFullScreenContent: (RewardedAd dismissed) {
              dismissed.dispose();
              if (!result.isCompleted) result.complete(earned);
            },
            onAdFailedToShowFullScreenContent:
                (RewardedAd failed, AdError error) {
                  failed.dispose();
                  if (!result.isCompleted) result.complete(false);
                },
          );
          try {
            await ad.show(
              onUserEarnedReward: (AdWithoutView _, RewardItem __) {
                earned = true;
              },
            );
          } on Object {
            ad.dispose();
            if (!result.isCompleted) result.complete(false);
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (!result.isCompleted) result.complete(false);
        },
      ),
    );
    return result.future;
  }

  static AdConsentState _mapConsent(ConsentStatus status) => switch (status) {
    ConsentStatus.unknown => AdConsentState.unknown,
    ConsentStatus.required => AdConsentState.required,
    ConsentStatus.obtained => AdConsentState.granted,
    ConsentStatus.notRequired => AdConsentState.granted,
  };
}

final class GoogleMobileAdsService implements AdsService {
  GoogleMobileAdsService({
    required Future<bool> Function() isEligible,
    GoogleAdsConfig? config,
    MobileAdsRuntime? runtime,
  }) : _isEligible = isEligible,
       _config = config ?? GoogleAdsConfig.forPlatform(defaultTargetPlatform),
       _runtime = runtime ?? const GoogleMobileAdsRuntime();

  final Future<bool> Function() _isEligible;
  final GoogleAdsConfig _config;
  final MobileAdsRuntime _runtime;

  AdConsentState _consentState = AdConsentState.unknown;
  Future<void>? _consentRefresh;
  bool _initialized = false;

  @override
  AdConsentState get consentState => _consentState;

  Future<void> refreshConsentInfo() {
    return _consentRefresh ??= _refreshConsentInfo().whenComplete(() {
      _consentRefresh = null;
    });
  }

  Future<void> _refreshConsentInfo() async {
    if (!await _eligible()) return;
    try {
      _consentState = await _runtime.refreshConsentInfo();
    } on Object {
      if (await _runtime.canRequestAds()) {
        _consentState = AdConsentState.granted;
      }
    }
  }

  @override
  Widget? bannerFor(AdPlacement placement) {
    return _GoogleAdaptiveBanner(service: this, placement: placement);
  }

  @override
  Future<bool> showRewarded(Reward reward) async {
    if (!await _prepareAds()) return false;
    return _runtime.showRewarded(
      adUnitId: _config.rewardedId,
      userId: reward.ssvUserId,
      customData: reward.ssvCustomData,
    );
  }

  Future<bool> _prepareAds() async {
    if (!await _eligible()) return false;
    if (_consentState == AdConsentState.unknown) {
      await refreshConsentInfo();
    }
    if (_consentState == AdConsentState.required) {
      _consentState = await _runtime.gatherConsentIfRequired();
    }
    if (!await _runtime.canRequestAds()) {
      if (_consentState != AdConsentState.required) {
        _consentState = AdConsentState.denied;
      }
      return false;
    }
    if (!_initialized) {
      await _runtime.initialize();
      _initialized = true;
    }
    return true;
  }

  Future<bool> _eligible() async {
    try {
      return await _isEligible();
    } on Object {
      return false;
    }
  }
}

final class _GoogleAdaptiveBanner extends StatefulWidget {
  const _GoogleAdaptiveBanner({required this.service, required this.placement});

  final GoogleMobileAdsService service;
  final AdPlacement placement;

  @override
  State<_GoogleAdaptiveBanner> createState() => _GoogleAdaptiveBannerState();
}

final class _GoogleAdaptiveBannerState extends State<_GoogleAdaptiveBanner> {
  int? _width;
  Future<BannerAd?>? _future;
  BannerAd? _ad;

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int width = constraints.maxWidth.floor();
        if (width <= 0) return const SizedBox.shrink();
        if (_width != width) {
          _width = width;
          _ad?.dispose();
          _ad = null;
          _future = _load(width);
        }
        return FutureBuilder<BannerAd?>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<BannerAd?> snapshot) {
            final BannerAd? ad = snapshot.data;
            if (ad == null) return const SizedBox.shrink();
            return SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            );
          },
        );
      },
    );
  }

  Future<BannerAd?> _load(int width) async {
    if (!await widget.service._prepareAds()) return null;
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return null;

    final Completer<BannerAd?> result = Completer<BannerAd?>();
    late final BannerAd ad;
    ad = BannerAd(
      size: size,
      adUnitId: widget.service._config.bannerId(widget.placement),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad loaded) {
          if (!mounted) {
            loaded.dispose();
            if (!result.isCompleted) result.complete(null);
            return;
          }
          _ad = ad;
          if (!result.isCompleted) result.complete(ad);
        },
        onAdFailedToLoad: (Ad failed, LoadAdError error) {
          failed.dispose();
          if (!result.isCompleted) result.complete(null);
        },
      ),
    );
    await ad.load();
    return result.future;
  }
}
