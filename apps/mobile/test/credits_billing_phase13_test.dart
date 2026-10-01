import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/router/app_routes.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/api/idempotency.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/billing/data/repositories/api_billing_repository.dart';
import 'package:savestream_mobile/features/billing/domain/models/billing_models.dart';
import 'package:savestream_mobile/features/credits/data/repositories/api_credits_repository.dart';
import 'package:savestream_mobile/features/credits/domain/models/credit_models.dart';

void main() {
  AppConfig config() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  ApiCreditsRepository creditsRepository(_FakeAdapter adapter) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return ApiCreditsRepository(apiClient: ApiClient(config: config(), dio: dio));
  }

  ApiBillingRepository billingRepository(
    _FakeAdapter adapter, {
    IdempotencyKeyGenerator? keyGenerator,
  }) {
    final Dio dio = Dio()..httpClientAdapter = adapter;
    return ApiBillingRepository(
      apiClient: ApiClient(config: config(), dio: dio),
      idempotencyKeyGenerator: keyGenerator,
      pollInterval: Duration.zero,
    );
  }

  test('credits overview maps integer balance ledger reservations and pricing', () async {
    final Map<String, int> calls = <String, int>{};
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      calls[options.path] = (calls[options.path] ?? 0) + 1;
      switch (options.path) {
        case '/v1/credits/balance':
          return _jsonResponse(200, <String, Object?>{
            'posted': 100,
            'reserved': 30,
            'available': 70,
          });
        case '/v1/credits/transactions':
          if (options.queryParameters['cursor'] == null) {
            return _jsonResponse(200, <String, Object?>{
              'items': <Object?>[
                _transactionJson(
                  id: 'txn-1',
                  type: 'grant',
                  amount: 100,
                  balanceAfter: 100,
                  referenceType: 'payment_order',
                  referenceId: 'order-1',
                ),
              ],
              'pagination': <String, Object?>{
                'next_cursor': 'txn-cursor-2',
                'has_more': true,
              },
            });
          }
          expect(options.queryParameters['cursor'], 'txn-cursor-2');
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[
              _transactionJson(
                id: 'txn-2',
                type: 'charge',
                amount: -20,
                balanceAfter: 80,
                referenceType: 'recording',
                referenceId: 'rec-1',
              ),
            ],
            'pagination': <String, Object?>{
              'next_cursor': null,
              'has_more': false,
            },
          });
        case '/v1/credits/reservations':
          return _jsonResponse(200, <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'id': 'reservation-1',
                'recording_id': 'rec-2',
                'reserved': 30,
                'settled': 0,
                'released': 0,
                'status': 'active',
                'created_at': '2026-10-01T06:00:00Z',
              },
            ],
            'pagination': <String, Object?>{
              'next_cursor': null,
              'has_more': false,
            },
          });
        case '/v1/pricing':
          return _jsonResponse(200, <String, Object?>{
            'version': 'pricing-v2',
            'credit_unit': 'credit',
            'rules': <Object?>[
              <String, Object?>{
                'label': 'Recording cost is backend policy',
              },
            ],
          });
        default:
          throw StateError('Unexpected path: ${options.path}');
      }
    });

    final CreditsOverview overview = await creditsRepository(adapter)
        .getOverview();

    expect(overview.balance.posted, 100);
    expect(overview.balance.reserved, 30);
    expect(overview.balance.available, 70);
    expect(overview.transactions.length, 2);
    expect(overview.transactions.last.amount, -20);
    expect(overview.transactions.last.recordingId, 'rec-1');
    expect(overview.reservations.single.status, CreditReservationStatus.active);
    expect(overview.activeReservationCount, 1);
    expect(overview.pricing?.version, 'pricing-v2');
    expect(calls['/v1/credits/transactions'], 2);
  });

  test('pricing SERVICE_UNAVAILABLE does not hide real balance and ledger', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (options.path == '/v1/credits/balance') {
        return _jsonResponse(200, <String, Object?>{
          'posted': 3,
          'reserved': 0,
          'available': 3,
        });
      }
      if (options.path == '/v1/pricing') {
        return _errorResponse(
          503,
          code: 'SERVICE_UNAVAILABLE',
          message: 'Pricing is not configured',
        );
      }
      return _jsonResponse(200, <String, Object?>{
        'items': <Object?>[],
        'pagination': <String, Object?>{
          'next_cursor': null,
          'has_more': false,
        },
      });
    });

    final CreditsOverview overview = await creditsRepository(adapter)
        .getOverview();

    expect(overview.balance.available, 3);
    expect(overview.pricing, isNull);
  });

  test('billing snapshot maps packages money and every payment status', () async {
    final List<String> statuses = <String>[
      'created',
      'pending',
      'paid',
      'failed',
      'cancelled',
      'expired',
      'partially_refunded',
      'refunded',
    ];
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (options.path == '/v1/billing/packages') {
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'id': 'pkg-1',
              'name': 'Starter',
              'credits': 25,
              'price': <String, Object?>{
                'amount_minor': 999,
                'currency': 'USD',
              },
              'active': true,
            },
          ],
        });
      }
      if (options.path == '/v1/billing/payment-orders') {
        return _jsonResponse(200, <String, Object?>{
          'items': <Object?>[
            for (int index = 0; index < statuses.length; index += 1)
              _orderJson(
                id: 'order-$index',
                status: statuses[index],
              ),
          ],
          'pagination': <String, Object?>{
            'next_cursor': null,
            'has_more': false,
          },
        });
      }
      throw StateError('Unexpected path: ${options.path}');
    });

    final BillingSnapshot snapshot = await billingRepository(adapter)
        .getSnapshot();

    expect(snapshot.packages.single.credits, 25);
    expect(snapshot.packages.single.price.amountMinor, 999);
    expect(snapshot.packages.single.price.currency, 'USD');
    expect(
      snapshot.orders.map((PaymentOrder order) => order.status).toList(),
      PaymentOrderStatus.values,
    );
  });

  test('create order reuses one UUID idempotency key after network failure', () async {
    int createCalls = 0;
    final List<Object?> keys = <Object?>[];
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (options.path != '/v1/billing/payment-orders' ||
          options.method != 'POST') {
        throw StateError('Unexpected billing request.');
      }
      createCalls += 1;
      keys.add(options.headers['Idempotency-Key']);
      if (createCalls == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return _jsonResponse(201, _orderJson(id: 'order-created'));
    });
    final ApiBillingRepository repository = billingRepository(
      adapter,
      keyGenerator: _SequenceUuidGenerator(),
    );

    await expectLater(
      repository.createPaymentOrder('pkg-1'),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiExceptionKind.network,
        ),
      ),
    );
    final PaymentOrder? order = await repository.createPaymentOrder('pkg-1');

    expect(order?.id, 'order-created');
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
    expect(
      keys.first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
          r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('checkout posts absolute return URI and reuses idempotency on retry', () async {
    int checkoutCalls = 0;
    final List<Object?> keys = <Object?>[];
    final Uri returnUri = AppRoutes.billingReturnUri('order-1');
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.path, '/v1/billing/payment-orders/order-1/checkout');
      checkoutCalls += 1;
      keys.add(options.headers['Idempotency-Key']);
      expect(options.data, <String, Object?>{
        'return_url': returnUri.toString(),
      });
      if (checkoutCalls == 1) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return _jsonResponse(200, <String, Object?>{
        'checkout_url': 'https://pay.example.com/session-1',
        'payment_order': _orderJson(
          id: 'order-1',
          status: 'pending',
        ),
      });
    });
    final ApiBillingRepository repository = billingRepository(
      adapter,
      keyGenerator: _SequenceUuidGenerator(),
    );

    expect(returnUri.scheme, 'savestream');
    expect(returnUri.path, AppRoutes.billingReturn);
    expect(returnUri.queryParameters['order_id'], 'order-1');

    await expectLater(
      repository.createCheckout(orderId: 'order-1', returnUri: returnUri),
      throwsA(isA<ApiException>()),
    );
    final CheckoutSession? checkout = await repository.createCheckout(
      orderId: 'order-1',
      returnUri: returnUri,
    );

    expect(checkout?.paymentOrder.status, PaymentOrderStatus.pending);
    expect(checkout?.checkoutUri.host, 'pay.example.com');
    expect(keys[0], keys[1]);
  });

  test('payment polling stops only after backend reaches paid', () async {
    int pollCalls = 0;
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      expect(options.method, 'GET');
      expect(options.path, '/v1/billing/payment-orders/order-1');
      pollCalls += 1;
      final String status = switch (pollCalls) {
        1 => 'created',
        2 => 'pending',
        _ => 'paid',
      };
      return _jsonResponse(
        200,
        _orderJson(id: 'order-1', status: status),
      );
    });

    final List<PaymentOrder?> orders = await billingRepository(
      adapter,
    ).watchPaymentOrder('order-1').toList();

    expect(
      orders.whereType<PaymentOrder>().map((PaymentOrder item) => item.status),
      <PaymentOrderStatus>[
        PaymentOrderStatus.created,
        PaymentOrderStatus.pending,
        PaymentOrderStatus.paid,
      ],
    );
    expect(pollCalls, 3);
  });

  test('paid order snapshot never mutates credit balance client-side', () async {
    final _FakeAdapter adapter = _FakeAdapter((
      RequestOptions options,
      int call,
    ) {
      if (options.path == '/v1/billing/payment-orders/order-1') {
        return _jsonResponse(
          200,
          _orderJson(id: 'order-1', status: 'paid'),
        );
      }
      if (options.path == '/v1/credits/balance') {
        return _jsonResponse(200, <String, Object?>{
          'posted': 40,
          'reserved': 5,
          'available': 35,
        });
      }
      throw StateError('Unexpected path: ${options.path}');
    });

    final PaymentOrder? paid = await billingRepository(
      adapter,
    ).refreshPaymentOrder('order-1');
    final CreditBalance balance = await creditsRepository(adapter).getBalance();

    expect(paid?.status, PaymentOrderStatus.paid);
    expect(paid?.credits, 25);
    expect(balance.posted, 40);
    expect(balance.available, 35);
  });
}

Map<String, Object?> _transactionJson({
  required String id,
  required String type,
  required int amount,
  required int balanceAfter,
  required String referenceType,
  String? referenceId,
}) {
  return <String, Object?>{
    'id': id,
    'type': type,
    'amount': amount,
    'balance_after': balanceAfter,
    'reference_type': referenceType,
    'reference_id': referenceId,
    'created_at': '2026-10-01T06:00:00Z',
  };
}

Map<String, Object?> _orderJson({
  required String id,
  String status = 'created',
}) {
  return <String, Object?>{
    'id': id,
    'package_id': 'pkg-1',
    'status': status,
    'credits': 25,
    'amount': <String, Object?>{
      'amount_minor': 999,
      'currency': 'USD',
    },
    'provider': status == 'created' ? null : 'provider-x',
    'provider_reference': status == 'created' ? null : 'provider-ref',
    'created_at': '2026-10-01T06:00:00Z',
    'updated_at': '2026-10-01T06:01:00Z',
  };
}

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

ResponseBody _errorResponse(
  int statusCode, {
  required String code,
  required String message,
}) {
  return _jsonResponse(statusCode, <String, Object?>{
    'error': <String, Object?>{
      'code': code,
      'message': message,
      'request_id': 'req_phase13',
      'retryable': false,
      'details': <String, Object?>{},
    },
  });
}

typedef _FakeHandler =
    FutureOr<ResponseBody> Function(RequestOptions options, int call);

final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final _FakeHandler _handler;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    return _handler(options, calls);
  }

  @override
  void close({bool force = false}) {}
}

final class _SequenceUuidGenerator implements IdempotencyKeyGenerator {
  int _value = 0;

  @override
  String nextKey() {
    _value += 1;
    final String suffix = _value.toString().padLeft(12, '0');
    return '00000000-0000-4000-8000-$suffix';
  }
}
