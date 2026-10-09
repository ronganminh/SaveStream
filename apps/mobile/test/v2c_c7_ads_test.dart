import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/rewards/data/repositories/api_reward_repository.dart';
import 'package:savestream_mobile/features/rewards/domain/models/reward.dart';
import 'package:savestream_mobile/platform/contracts/ads_service.dart';
import 'package:savestream_mobile/platform/google_mobile_ads_service.dart';

void main() {
  test('C7 Android production defaults use the configured SaveStream IDs', () {
    final GoogleAdsConfig config = GoogleAdsConfig.forPlatform(
      TargetPlatform.android,
      useProductionIds: true,
    );

    expect(config.bannerHomeId, 'ca-app-pub-2078852906622512/4061426634');
    expect(config.bannerWatchListId, 'ca-app-pub-2078852906622512/4061426634');
    expect(config.bannerLibraryId, 'ca-app-pub-2078852906622512/4061426634');
    expect(config.rewardedId, 'ca-app-pub-2078852906622512/5155016450');
  });

  test('C7 Android debug defaults keep Google test ad units', () {
    final GoogleAdsConfig config = GoogleAdsConfig.forPlatform(
      TargetPlatform.android,
      useProductionIds: false,
    );

    expect(config.bannerHomeId, 'ca-app-pub-3940256099942544/9214589741');
    expect(config.rewardedId, 'ca-app-pub-3940256099942544/5224354917');
  });

  test(
    'C7 reward API sends purpose/session and preserves SSV metadata',
    () async {
      final ApiRewardRepository repository = ApiRewardRepository(
        apiClient: _clientFor(
          _FakeAdapter((RequestOptions options) {
            if (options.method == 'POST') {
              expect(options.path, '/v1/rewards');
              expect(options.data, <String, Object?>{
                'purpose': 'local_minutes',
                'session_id': 'session_1',
              });
              return _jsonResponse(201, <String, Object?>{
                'reward_id': 'rwd_1',
                'ssv_user_id': 'usr_1',
                'ssv_custom_data': 'rwd_1',
                'expires_at': '2026-10-06T00:00:00Z',
              });
            }
            expect(options.method, 'GET');
            expect(options.path, '/v1/rewards/rwd_1');
            return _jsonResponse(200, <String, Object?>{
              'reward_id': 'rwd_1',
              'status': 'valid',
            });
          }),
        ),
      );

      final Reward created = await repository.create(
        purpose: RewardPurpose.localMinutes,
        sessionId: 'session_1',
      );
      final Reward verified = await repository.getStatus(created.rewardId);

      expect(created.ssvUserId, 'usr_1');
      expect(created.ssvCustomData, 'rwd_1');
      expect(verified.status, RewardStatus.valid);
      expect(verified.ssvUserId, 'usr_1');
      expect(verified.sessionId, 'session_1');
    },
  );

  test('C7 ineligible users never touch UMP or initialize ads', () async {
    final _FakeAdsRuntime runtime = _FakeAdsRuntime();
    final GoogleMobileAdsService service = GoogleMobileAdsService(
      isEligible: () async => false,
      runtime: runtime,
      config: _config,
    );

    await service.refreshConsentInfo();
    final bool shown = await service.showRewarded(_reward);

    expect(shown, isFalse);
    expect(service.consentState, AdConsentState.unknown);
    expect(runtime.refreshCalls, 0);
    expect(runtime.gatherCalls, 0);
    expect(runtime.initializeCalls, 0);
    expect(runtime.rewardedCalls, 0);
  });

  test('C7 consent state stream updates after UMP result', () async {
    final _FakeAdsRuntime runtime = _FakeAdsRuntime(
      refreshState: AdConsentState.required,
      gatheredState: AdConsentState.granted,
      canRequest: true,
    );
    final GoogleMobileAdsService service = GoogleMobileAdsService(
      isEligible: () async => true,
      runtime: runtime,
      config: _config,
    );
    final List<AdConsentState> states = <AdConsentState>[];
    final subscription = service.consentStates.listen(states.add);
    addTearDown(subscription.cancel);

    await service.refreshConsentInfo();
    await service.requestConsent();
    await Future<void>.delayed(Duration.zero);

    expect(
      states,
      containsAllInOrder(<AdConsentState>[
        AdConsentState.unknown,
        AdConsentState.required,
        AdConsentState.granted,
      ]),
    );
  });

  testWidgets('C7 banner stays zero-size when ads are ineligible', (
    WidgetTester tester,
  ) async {
    final _FakeAdsRuntime runtime = _FakeAdsRuntime();
    final GoogleMobileAdsService service = GoogleMobileAdsService(
      isEligible: () async => false,
      runtime: runtime,
      config: _config,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 390, child: service.bannerFor(AdPlacement.home)),
      ),
    );
    await tester.pumpAndSettle();

    expect(runtime.initializeCalls, 0);
    expect(runtime.refreshCalls, 0);
  });

  test(
    'C7 gathers required consent, initializes once, and sends SSV',
    () async {
      final _FakeAdsRuntime runtime = _FakeAdsRuntime(
        refreshState: AdConsentState.required,
        gatheredState: AdConsentState.granted,
        canRequest: true,
      );
      final GoogleMobileAdsService service = GoogleMobileAdsService(
        isEligible: () async => true,
        runtime: runtime,
        config: _config,
      );

      final bool beforeConsent = await service.showRewarded(_reward);
      expect(beforeConsent, isFalse);
      expect(runtime.gatherCalls, 0);
      expect(runtime.initializeCalls, 0);
      expect(runtime.rewardedCalls, 0);

      await service.requestConsent();
      final bool first = await service.showRewarded(_reward);
      final bool second = await service.showRewarded(_reward);

      expect(first, isTrue);
      expect(second, isTrue);
      expect(service.consentState, AdConsentState.granted);
      expect(runtime.gatherCalls, 1);
      expect(runtime.initializeCalls, 1);
      expect(runtime.rewardedCalls, 2);
      expect(runtime.lastAdUnitId, 'rewarded-test');
      expect(runtime.lastUserId, 'usr_ssv');
      expect(runtime.lastCustomData, 'rwd_ssv');
    },
  );

  test(
    'C7 denied consent does not initialize or request rewarded ad',
    () async {
      final _FakeAdsRuntime runtime = _FakeAdsRuntime(
        refreshState: AdConsentState.required,
        gatheredState: AdConsentState.denied,
        canRequest: false,
      );
      final GoogleMobileAdsService service = GoogleMobileAdsService(
        isEligible: () async => true,
        runtime: runtime,
        config: _config,
      );

      await service.requestConsent();
      final bool shown = await service.showRewarded(_reward);

      expect(shown, isFalse);
      expect(service.consentState, AdConsentState.denied);
      expect(runtime.initializeCalls, 0);
      expect(runtime.rewardedCalls, 0);
    },
  );
}

const GoogleAdsConfig _config = GoogleAdsConfig(
  bannerHomeId: 'home-test',
  bannerWatchListId: 'watch-test',
  bannerLibraryId: 'library-test',
  rewardedId: 'rewarded-test',
);

final Reward _reward = Reward(
  rewardId: 'rwd_ssv',
  purpose: RewardPurpose.localMinutes,
  status: RewardStatus.pending,
  ssvUserId: 'usr_ssv',
  ssvCustomData: 'rwd_ssv',
  expiresAt: DateTime.utc(2026, 10, 6),
);

final class _FakeAdsRuntime implements MobileAdsRuntime {
  _FakeAdsRuntime({
    this.refreshState = AdConsentState.granted,
    this.gatheredState = AdConsentState.granted,
    this.canRequest = true,
  });

  final AdConsentState refreshState;
  final AdConsentState gatheredState;
  final bool canRequest;

  int refreshCalls = 0;
  int gatherCalls = 0;
  int initializeCalls = 0;
  int rewardedCalls = 0;
  String? lastAdUnitId;
  String? lastUserId;
  String? lastCustomData;

  @override
  Future<AdConsentState> refreshConsentInfo() async {
    refreshCalls += 1;
    return refreshState;
  }

  @override
  Future<AdConsentState> gatherConsentIfRequired() async {
    gatherCalls += 1;
    return gatheredState;
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
  }

  @override
  Future<bool> showRewarded({
    required String adUnitId,
    required String userId,
    required String customData,
  }) async {
    rewardedCalls += 1;
    lastAdUnitId = adUnitId;
    lastUserId = userId;
    lastCustomData = customData;
    return true;
  }
}

ApiClient _clientFor(HttpClientAdapter adapter) {
  final Dio dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    config: AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    ),
    dio: dio,
  );
}

ResponseBody _jsonResponse(int status, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );
}

typedef _Handler = ResponseBody Function(RequestOptions options);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _Handler _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);

  @override
  void close({bool force = false}) {}
}
