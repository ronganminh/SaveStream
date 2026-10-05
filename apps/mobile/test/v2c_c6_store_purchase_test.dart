import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/store/data/repositories/api_store_repository.dart';
import 'package:savestream_mobile/features/store/domain/models/store_models.dart';
import 'package:savestream_mobile/features/store/domain/repositories/store_purchase_retry_store.dart';
import 'package:savestream_mobile/features/store/domain/repositories/store_repository.dart';
import 'package:savestream_mobile/features/store/presentation/a5_purchase_controller.dart';
import 'package:savestream_mobile/features/store/presentation/a5_store_providers.dart';
import 'package:savestream_mobile/platform/contracts/purchase_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  test(
    'C6 package list uses backend store product ids and cloud minutes',
    () async {
      final ApiStoreRepository repository = ApiStoreRepository(
        apiClient: _clientFor(
          _FakeAdapter((RequestOptions options) {
            expect(options.method, 'GET');
            expect(options.path, '/v1/billing/packages');
            return _jsonResponse(200, <String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'id': 'pkg_50',
                  'name': 'Starter',
                  'credits': 3000,
                  'price': <String, Object?>{
                    'amount_minor': 999,
                    'currency': 'USD',
                  },
                  'active': true,
                  'store_product_ids': <String, Object?>{
                    'app_store': 'savestream.hours.50',
                    'google_play': 'savestream.hours.50',
                  },
                  'cloud_minutes': 3000,
                },
              ],
            });
          }),
        ),
      );

      final List<StorePackage> packages = await repository.listPackages();

      expect(packages, hasLength(1));
      expect(packages.single.cloudMinutes, 3000);
      expect(packages.single.productIds.appStore, 'savestream.hours.50');
      expect(packages.single.productIds.googlePlay, 'savestream.hours.50');
    },
  );

  test(
    'C6 posts receipt and transaction to backend for verification',
    () async {
      final ApiStoreRepository repository = ApiStoreRepository(
        apiClient: _clientFor(
          _FakeAdapter((RequestOptions options) {
            expect(options.method, 'POST');
            expect(options.path, '/v1/billing/store-purchases');
            expect(options.data, <String, Object?>{
              'platform': 'app_store',
              'product_id': 'savestream.hours.50',
              'transaction_id': 'txn_123',
              'receipt': 'signed-jws',
            });
            return _jsonResponse(200, <String, Object?>{
              'status': 'credited',
              'payment_order_id': 'ord_123',
              'cloud_minutes_added': 3000,
              'cloud_minutes_available': 4200,
            });
          }),
        ),
      );

      final StorePurchaseResult result = await repository.submitPurchase(
        const StorePurchaseRequest(
          platform: StorePurchasePlatform.appStore,
          productId: 'savestream.hours.50',
          transactionId: 'txn_123',
          receipt: 'signed-jws',
        ),
      );

      expect(result.status, StorePurchaseStatus.credited);
      expect(result.cloudMinutesAdded, 3000);
      expect(result.cloudMinutesAvailable, 4200);
    },
  );

  test('C6 maps backend pending without granting success locally', () async {
    final ApiStoreRepository repository = ApiStoreRepository(
      apiClient: _clientFor(
        _FakeAdapter(
          (RequestOptions options) => _jsonResponse(200, <String, Object?>{
            'status': 'pending',
            'payment_order_id': 'ord_pending',
            'cloud_minutes_added': 0,
            'cloud_minutes_available': 1200,
          }),
        ),
      ),
    );

    final StorePurchaseResult result = await repository.submitPurchase(
      const StorePurchaseRequest(
        platform: StorePurchasePlatform.googlePlay,
        productId: 'savestream.hours.150',
        transactionId: 'gpa.123',
        receipt: 'purchase-token',
      ),
    );

    expect(result.status, StorePurchaseStatus.pending);
    expect(result.cloudMinutesAdded, 0);
  });

  test('C6 completes store purchase only after backend credits it', () async {
    final _TestPurchaseService purchaseService = _TestPurchaseService();
    final _TestStoreRepository storeRepository = _TestStoreRepository(
      StorePurchaseStatus.credited,
    );
    final _TestRetryStore retryStore = _TestRetryStore();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(purchaseService),
        storeRepositoryProvider.overrideWithValue(storeRepository),
        storePurchaseRetryStoreProvider.overrideWithValue(retryStore),
        deviceInfoServiceProvider.overrideWithValue(
          const FakeDeviceInfoService(platform: DevicePlatform.android),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await purchaseService.dispose();
    });

    container.read(cloudHoursPurchaseControllerProvider);
    purchaseService.emit(
      const PurchaseServiceEvent(
        productId: 'savestream.hours.50',
        status: PurchaseEventStatus.purchased,
        transactionId: 'gpa.credited',
        receipt: 'purchase-token',
      ),
    );

    await _waitFor(
      () =>
          container.read(cloudHoursPurchaseControllerProvider).phase ==
          CloudHoursPurchasePhase.credited,
    );

    expect(storeRepository.requests, hasLength(1));
    expect(
      storeRepository.requests.single.platform,
      StorePurchasePlatform.googlePlay,
    );
    expect(purchaseService.completedTransactions, <String>['gpa.credited']);
    expect(await retryStore.load(), isEmpty);
  });

  test(
    'C6 keeps pending purchase for retry and does not complete store',
    () async {
      final _TestPurchaseService purchaseService = _TestPurchaseService();
      final _TestStoreRepository storeRepository = _TestStoreRepository(
        StorePurchaseStatus.pending,
      );
      final _TestRetryStore retryStore = _TestRetryStore();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          purchaseServiceProvider.overrideWithValue(purchaseService),
          storeRepositoryProvider.overrideWithValue(storeRepository),
          storePurchaseRetryStoreProvider.overrideWithValue(retryStore),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.ios),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await purchaseService.dispose();
      });

      container.read(cloudHoursPurchaseControllerProvider);
      purchaseService.emit(
        const PurchaseServiceEvent(
          productId: 'savestream.hours.150',
          status: PurchaseEventStatus.purchased,
          transactionId: 'ios.pending',
          receipt: 'signed-jws',
        ),
      );

      await _waitFor(
        () =>
            container.read(cloudHoursPurchaseControllerProvider).phase ==
            CloudHoursPurchasePhase.pending,
      );

      expect(
        storeRepository.requests.single.platform,
        StorePurchasePlatform.appStore,
      );
      expect(purchaseService.completedTransactions, isEmpty);
      expect((await retryStore.load()).single.transactionId, 'ios.pending');
    },
  );

  test(
    'C6 distinguishes user cancellation without backend submission',
    () async {
      final _TestPurchaseService purchaseService = _TestPurchaseService();
      final _TestStoreRepository storeRepository = _TestStoreRepository(
        StorePurchaseStatus.credited,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [
          purchaseServiceProvider.overrideWithValue(purchaseService),
          storeRepositoryProvider.overrideWithValue(storeRepository),
          storePurchaseRetryStoreProvider.overrideWithValue(_TestRetryStore()),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await purchaseService.dispose();
      });

      container.read(cloudHoursPurchaseControllerProvider);
      purchaseService.emit(
        const PurchaseServiceEvent(
          productId: 'savestream.hours.400',
          status: PurchaseEventStatus.cancelled,
        ),
      );

      await _waitFor(
        () =>
            container.read(cloudHoursPurchaseControllerProvider).phase ==
            CloudHoursPurchasePhase.cancelled,
      );
      expect(storeRepository.requests, isEmpty);
      expect(purchaseService.completedTransactions, isEmpty);
    },
  );
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
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _waitFor(bool Function() predicate) async {
  for (int attempt = 0; attempt < 50; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for purchase state.');
}

final class _TestPurchaseService implements PurchaseService {
  final StreamController<PurchaseServiceEvent> _events =
      StreamController<PurchaseServiceEvent>.broadcast();
  final List<String> completedTransactions = <String>[];

  @override
  Stream<PurchaseServiceEvent> get purchaseEvents => _events.stream;

  void emit(PurchaseServiceEvent event) => _events.add(event);

  @override
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids) async => ids
      .map((String id) => StoreProductInfo(id: id, localizedPrice: r'$9.99'))
      .toList(growable: false);

  @override
  Future<void> buy(String productId) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<void> completePurchase(String transactionId) async {
    completedTransactions.add(transactionId);
  }

  Future<void> dispose() => _events.close();
}

final class _TestStoreRepository implements StoreRepository {
  _TestStoreRepository(this.status);

  final StorePurchaseStatus status;
  final List<StorePurchaseRequest> requests = <StorePurchaseRequest>[];

  @override
  Future<List<StorePackage>> listPackages() async => const <StorePackage>[];

  @override
  Future<StorePurchaseResult> submitPurchase(
    StorePurchaseRequest request,
  ) async {
    requests.add(request);
    return StorePurchaseResult(
      status: status,
      paymentOrderId: 'ord_test',
      cloudMinutesAdded: status == StorePurchaseStatus.credited ? 3000 : 0,
      cloudMinutesAvailable: 3000,
    );
  }
}

final class _TestRetryStore implements StorePurchaseRetryStore {
  final Map<String, StorePurchaseRequest> _items =
      <String, StorePurchaseRequest>{};

  @override
  Future<List<StorePurchaseRequest>> load() async =>
      List<StorePurchaseRequest>.unmodifiable(_items.values);

  @override
  Future<void> put(StorePurchaseRequest request) async {
    _items[request.transactionId] = request;
  }

  @override
  Future<void> remove(String transactionId) async {
    _items.remove(transactionId);
  }
}
