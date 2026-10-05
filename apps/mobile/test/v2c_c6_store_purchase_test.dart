import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/store/data/repositories/api_store_repository.dart';
import 'package:savestream_mobile/features/store/domain/models/store_models.dart';

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
