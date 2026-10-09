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

  factory GoogleAdsConfig.forPlatform(
    TargetPlatform platform, {
    bool useProductionIds = kReleaseMode,
  }) {
    final bool ios = platform == TargetPlatform.iOS;
    const String bannerHomeIos = String.fromEnvironment(
      'ADMOB_BANNER_HOME_IOS',
    );
    const String bannerHomeAndroid = String.fromEnvironment(
      'ADMOB_BANNER_HOME_ANDROID',
    );
    const String bannerWatchIos = String.fromEnvironment(
      'ADMOB_BANNER_WATCH_IOS',
    );
    const String bannerWatchAndroid = String.fromEnvironment(
      'ADMOB_BANNER_WATCH_ANDROID',
    );
    const String bannerLibraryIos = String.fromEnvironment(
      'ADMOB_BANNER_LIBRARY_IOS',
    );
    const String bannerLibraryAndroid = String.fromEnvironment(
      'ADMOB_BANNER_LIBRARY_ANDROID',
    );
    const String rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');
    const String rewardedAndroid = String.fromEnvironment(
      'ADMOB_REWARDED_ANDROID',
    );

    const String androidTestBannerId = 'ca-app-pub-3940256099942544/9214589741';
    const String androidProductionBannerId =
        'ca-app-pub-2078852906622512/4061426634';
    const String androidTestRewardedId =
        'ca-app-pub-3940256099942544/5224354917';
    const String androidProductionRewardedId =
        'ca-app-pub-2078852906622512/5155016450';

    String configuredOr(String configured, String fallback) =>
        configured.trim().isEmpty ? fallback : configured.trim();

    final String androidBannerFallback = useProductionIds
        ? androidProductionBannerId
        : androidTestBannerId;
    final String androidRewardedFallback = useProductionIds
        ? androidProductionRewardedId
        : androidTestRewardedId;
    return GoogleAdsConfig(
      bannerHomeId: ios
          ? configuredOr(
              bannerHomeIos,
              'ca-app-pub-3940256099942544/2435281174',
            )
          : configuredOr(bannerHomeAndroid, androidBannerFallback),
      bannerWatchListId: ios
          ? configuredOr(
              bannerWatchIos,
              'ca-app-pub-3940256099942544/2435281174',
            )
          : configuredOr(bannerWatchAndroid, androidBannerFallback),
      bannerLibraryId: ios
          ? configuredOr(
              bannerLibraryIos,
              'ca-app-pub-3940256099942544/2435281174',
            )
          : configuredOr(bannerLibraryAndroid, androidBannerFallback),
      rewardedId: ios
          ? configuredOr(rewardedIos, 'ca-app-pub-3940256099942544/1712485313')
          : configuredOr(rewardedAndroid, androidRewardedFallback),
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
  final StreamController<AdConsentState> _consentController =
      StreamController<AdConsentState>.broadcast();
  Future<void>? _consentRefresh;
  bool _initialized = false;

  @override
  AdConsentState get consentState => _consentState;

  @override
  Stream<AdConsentState> get consentStates async* {
    yield _consentState;
    yield* _consentController.stream;
  }

  Future<void> refreshConsentInfo() {
    return _consentRefresh ??= _refreshConsentInfo().whenComplete(() {
      _consentRefresh = null;
    });
  }

  Future<void> _refreshConsentInfo() async {
    if (!await _eligible()) return;
    try {
      _setConsentState(await _runtime.refreshConsentInfo());
    } on Object {
      if (await _runtime.canRequestAds()) {
        _setConsentState(AdConsentState.granted);
      }
    }
  }

  @override
  Future<void> requestConsent() async {
    if (!await _eligible()) return;
    if (_consentState == AdConsentState.unknown) {
      await refreshConsentInfo();
    }
    if (_consentState != AdConsentState.required) return;
    _setConsentState(await _runtime.gatherConsentIfRequired());
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
      return false;
    }
    if (!await _runtime.canRequestAds()) {
      _setConsentState(AdConsentState.denied);
      return false;
    }
    if (!_initialized) {
      await _runtime.initialize();
      _initialized = true;
    }
    return true;
  }

  void _setConsentState(AdConsentState next) {
    if (_consentState == next) return;
    _consentState = next;
    _consentController.add(next);
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
  StreamSubscription<AdConsentState>? _consentSubscription;
  AdConsentState? _lastConsentState;

  @override
  void initState() {
    super.initState();
    _listenToConsent(widget.service);
  }

  @override
  void didUpdateWidget(covariant _GoogleAdaptiveBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.service, widget.service)) {
      unawaited(_consentSubscription?.cancel());
      _lastConsentState = null;
      _listenToConsent(widget.service);
      _resetAd();
    }
  }

  @override
  void dispose() {
    unawaited(_consentSubscription?.cancel());
    _ad?.dispose();
    super.dispose();
  }

  void _listenToConsent(GoogleMobileAdsService service) {
    _consentSubscription = service.consentStates.listen((AdConsentState state) {
      final AdConsentState? previous = _lastConsentState;
      _lastConsentState = state;
      // An UNKNOWN -> GRANTED transition happens inside the in-flight load,
      // which can continue normally. A REQUIRED -> GRANTED transition occurs
      // after the consent sheet, so the earlier collapsed banner must retry.
      if (!mounted ||
          previous != AdConsentState.required ||
          state != AdConsentState.granted) {
        return;
      }
      setState(_resetAd);
    });
  }

  void _resetAd() {
    _ad?.dispose();
    _ad = null;
    _width = null;
    _future = null;
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
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
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
