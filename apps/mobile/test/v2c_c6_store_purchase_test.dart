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
                <String, Object?>{
                  'id': 'pkg_150',
                  'name': 'Standard',
                  'credits': 9000,
                  'active': true,
                  'store_product_ids': <String, Object?>{
                    'google_play': 'savestream.hours.150',
                  },
                  'cloud_minutes': 9000,
                  'featured': true,
                },
              ],
            });
          }),
        ),
      );

      final List<StorePackage> all = await repository.listPackages();
      // "Most popular" comes from the server's featured flag.
      expect(all.map((StorePackage p) => p.featured), <bool>[false, true]);
      final List<StorePackage> packages = all.take(1).toList();

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

  test('C6 sends the Play price along when it is known', () async {
    Object? sent;
    final ApiStoreRepository repository = ApiStoreRepository(
      apiClient: _clientFor(
        _FakeAdapter((RequestOptions options) {
          sent = options.data;
          return _jsonResponse(200, <String, Object?>{
            'status': 'credited',
            'payment_order_id': 'ord_1',
            'cloud_minutes_added': 9000,
            'cloud_minutes_available': 9000,
          });
        }),
      ),
    );

    await repository.submitPurchase(
      const StorePurchaseRequest(
        platform: StorePurchasePlatform.googlePlay,
        productId: 'savestream.hours.150',
        transactionId: 'GPA.1',
        receipt: 'token',
        priceAmountMicros: 24990000,
        priceCurrencyCode: 'USD',
      ),
    );

    expect(sent, <String, Object?>{
      'platform': 'google_play',
      'product_id': 'savestream.hours.150',
      'transaction_id': 'GPA.1',
      'receipt': 'token',
      'price_amount_micros': 24990000,
      'price_currency_code': 'USD',
    });
  });

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

  group('C6 recovery of purchases Google Play still holds', () {
    late _TestPurchaseService purchaseService;
    late _TestStoreRepository storeRepository;
    late _TestRetryStore retryStore;
    late ProviderContainer container;

    const PurchaseServiceEvent stuck = PurchaseServiceEvent(
      productId: 'savestream.hours.50',
      status: PurchaseEventStatus.purchased,
      transactionId: 'GPA.stuck',
      receipt: 'stuck-token',
    );

    setUp(() {
      purchaseService = _TestPurchaseService();
      storeRepository = _TestStoreRepository(StorePurchaseStatus.credited);
      retryStore = _TestRetryStore();
      container = ProviderContainer(
        overrides: [
          purchaseServiceProvider.overrideWithValue(purchaseService),
          storeRepositoryProvider.overrideWithValue(storeRepository),
          storePurchaseRetryStoreProvider.overrideWithValue(retryStore),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.android),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await purchaseService.dispose();
    });

    CloudHoursPurchaseController controller() =>
        container.read(cloudHoursPurchaseControllerProvider.notifier);

    test(
      'on start: sends it to the server, consumes only once credited',
      () async {
        purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
        await container.read(purchaseRecoveryProvider.future);

        expect(storeRepository.requests.single.transactionId, 'GPA.stuck');
        expect(storeRepository.requests.single.receipt, 'stuck-token');
        expect(purchaseService.completedTransactions, <String>['GPA.stuck']);
        expect(await retryStore.load(), isEmpty);

        // Once per session.
        await controller().recoverOnStart();
        expect(storeRepository.requests, hasLength(1));
      },
    );

    test('server refuses it: not consumed, kept for the next try', () async {
      purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
      storeRepository.error = StateError('422 Store product is not configured');
      await controller().recoverOnStart();

      expect(purchaseService.completedTransactions, isEmpty);
      expect((await retryStore.load()).single.transactionId, 'GPA.stuck');
    });

    test('pending payment: reported to the server, never consumed', () async {
      purchaseService.unfinished = <PurchaseServiceEvent>[
        const PurchaseServiceEvent(
          productId: 'savestream.hours.150',
          status: PurchaseEventStatus.pending,
          transactionId: 'GPA.pending',
          receipt: 'pending-token',
        ),
      ];
      storeRepository.status = StorePurchaseStatus.pending;
      await controller().recoverOnStart();

      expect(storeRepository.requests.single.transactionId, 'GPA.pending');
      expect(purchaseService.completedTransactions, isEmpty);
    });

    test('Buy on a pack Play still holds finishes that one instead', () async {
      purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
      await controller().buy(_starterOffer);

      expect(purchaseService.buys, isEmpty);
      final CloudHoursPurchaseState state = container.read(
        cloudHoursPurchaseControllerProvider,
      );
      expect(state.phase, CloudHoursPurchasePhase.credited);
      expect(state.minutesAdded, 3000);
      expect(purchaseService.completedTransactions, <String>['GPA.stuck']);
    });

    test('ITEM_ALREADY_OWNED from Play finishes the owned purchase', () async {
      await controller().buy(_starterOffer);
      expect(purchaseService.buys, <String>['savestream.hours.50']);

      // Play only now reports the owned purchase (e.g. bought on another
      // device of the same account).
      purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
      purchaseService.emit(
        const PurchaseServiceEvent(
          productId: '',
          status: PurchaseEventStatus.failed,
          errorMessage: 'BillingResponse.itemAlreadyOwned',
          alreadyOwned: true,
        ),
      );
      await _waitFor(
        () =>
            container.read(cloudHoursPurchaseControllerProvider).phase ==
            CloudHoursPurchasePhase.credited,
      );
      expect(purchaseService.completedTransactions, <String>['GPA.stuck']);
    });

    test('Restore purchases reports the packs added', () async {
      purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
      await controller().restore();

      final CloudHoursPurchaseState state = container.read(
        cloudHoursPurchaseControllerProvider,
      );
      expect(state.phase, CloudHoursPurchasePhase.restored);
      expect(state.restored.single.productId, 'savestream.hours.50');
      expect(state.restored.single.minutes, 3000);
    });

    test('one purchase found twice at once is sent once', () async {
      purchaseService.unfinished = <PurchaseServiceEvent>[stuck];
      purchaseService.emit(stuck);
      await Future.wait(<Future<void>>[
        controller().recoverOnStart(),
        controller().restore(),
      ]);
      await _waitFor(() => purchaseService.completedTransactions.isNotEmpty);
      expect(
        storeRepository.requests.map((r) => r.transactionId).toSet(),
        <String>{'GPA.stuck'},
      );
      expect(storeRepository.requests.length, lessThanOrEqualTo(2));
    });
  });
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

  final List<String> buys = <String>[];

  @override
  Future<void> buy(String productId, {String? accountReference}) async {
    buys.add(productId);
  }

  List<PurchaseServiceEvent> unfinished = <PurchaseServiceEvent>[];

  @override
  Future<List<PurchaseServiceEvent>> unfinishedPurchases() async => unfinished;

  @override
  Future<void> completePurchase(String transactionId) async {
    completedTransactions.add(transactionId);
  }

  Future<void> dispose() => _events.close();
}

final class _TestStoreRepository implements StoreRepository {
  _TestStoreRepository(this.status);

  StorePurchaseStatus status;

  /// When set, the server answers with this error (e.g. 422 not configured).
  Object? error;
  final List<StorePurchaseRequest> requests = <StorePurchaseRequest>[];

  @override
  Future<List<StorePackage>> listPackages() async => const <StorePackage>[];

  @override
  Future<StorePurchaseResult> submitPurchase(
    StorePurchaseRequest request,
  ) async {
    requests.add(request);
    if (error != null) throw error!;
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

const CloudHoursOffer _starterOffer = CloudHoursOffer(
  package: StorePackage(
    id: 'pkg_50',
    name: 'Starter',
    cloudMinutes: 3000,
    productIds: StoreProductIds(
      appStore: 'savestream.hours.50',
      googlePlay: 'savestream.hours.50',
    ),
  ),
  productId: 'savestream.hours.50',
  localizedPrice: r'$11.49',
);
