import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/idempotency.dart';
import '../../domain/models/billing_models.dart';
import '../../domain/repositories/billing_repository.dart';
import '../remote/billing_api_models.dart';

final class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository({
    required ApiClient apiClient,
    IdempotencyKeyGenerator? idempotencyKeyGenerator,
    Duration pollInterval = const Duration(seconds: 2),
  }) : _apiClient = apiClient,
       _idempotencyKeyGenerator =
           idempotencyKeyGenerator ?? SecureIdempotencyKeyGenerator(),
       _pollInterval = pollInterval;

  static const int _pageSize = 100;

  final ApiClient _apiClient;
  final IdempotencyKeyGenerator _idempotencyKeyGenerator;
  final Duration _pollInterval;

  final Map<String, IdempotencyContext> _createOrderContexts =
      <String, IdempotencyContext>{};
  final Map<String, _CheckoutOperation> _checkoutOperations =
      <String, _CheckoutOperation>{};

  @override
  Future<BillingSnapshot> getSnapshot() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      _listPackages(),
      _listOrders(),
    ]);
    return BillingSnapshot(
      packages: values[0] as List<CreditPackage>,
      orders: values[1] as List<PaymentOrder>,
    );
  }

  @override
  Future<PaymentOrder?> createPaymentOrder(String packageId) async {
    final IdempotencyContext context = _createOrderContexts.putIfAbsent(
      packageId,
      () => IdempotencyContext.create(_idempotencyKeyGenerator),
    );
    try {
      final response = await _apiClient.post<PaymentOrder>(
        '/v1/billing/payment-orders',
        data: <String, Object?>{'package_id': packageId},
        idempotency: context,
        decoder: paymentOrderFromJson,
      );
      _createOrderContexts.remove(packageId);
      return response.data;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _createOrderContexts.remove(packageId);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<CheckoutSession?> createCheckout({
    required String orderId,
    required Uri returnUri,
  }) async {
    final String returnValue = returnUri.toString();
    final _CheckoutOperation operation = _checkoutOperations.update(
      orderId,
      (_CheckoutOperation existing) {
        if (existing.returnUri == returnValue) {
          return existing;
        }
        return _CheckoutOperation(
          returnUri: returnValue,
          idempotency: IdempotencyContext.create(_idempotencyKeyGenerator),
        );
      },
      ifAbsent: () => _CheckoutOperation(
        returnUri: returnValue,
        idempotency: IdempotencyContext.create(_idempotencyKeyGenerator),
      ),
    );

    try {
      final response = await _apiClient.post<CheckoutSession>(
        '/v1/billing/payment-orders/$orderId/checkout',
        data: <String, Object?>{'return_url': returnValue},
        idempotency: operation.idempotency,
        decoder: checkoutSessionFromJson,
      );
      _checkoutOperations.remove(orderId);
      return response.data;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _checkoutOperations.remove(orderId);
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<PaymentOrder?> refreshPaymentOrder(String orderId) async {
    try {
      final response = await _apiClient.get<PaymentOrder>(
        '/v1/billing/payment-orders/$orderId',
        decoder: paymentOrderFromJson,
      );
      return response.data;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Stream<PaymentOrder?> watchPaymentOrder(String orderId) async* {
    while (true) {
      final PaymentOrder? order = await refreshPaymentOrder(orderId);
      yield order;
      if (order == null || order.status.isTerminal) {
        return;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<List<CreditPackage>> _listPackages() async {
    final response = await _apiClient.get<List<CreditPackage>>(
      '/v1/billing/packages',
      decoder: creditPackagesFromJson,
    );
    return List<CreditPackage>.unmodifiable(
      response.data.where((CreditPackage item) => item.active),
    );
  }

  Future<List<PaymentOrder>> _listOrders() async {
    final List<PaymentOrder> items = <PaymentOrder>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final response = await _apiClient.get<BillingApiPage<PaymentOrder>>(
        '/v1/billing/payment-orders',
        queryParameters: <String, dynamic>{
          'limit': _pageSize,
          if (cursor != null) 'cursor': cursor,
        },
        decoder: paymentOrdersFromJson,
      );
      final BillingApiPage<PaymentOrder> page = response.data;
      items.addAll(page.items);
      if (!page.hasMore) {
        return List<PaymentOrder>.unmodifiable(items);
      }
      final String nextCursor = page.nextCursor!;
      if (!seenCursors.add(nextCursor)) {
        throw const ApiException(
          kind: ApiExceptionKind.malformedResponse,
          retryable: false,
        );
      }
      cursor = nextCursor;
    }
  }
}

final class _CheckoutOperation {
  const _CheckoutOperation({
    required this.returnUri,
    required this.idempotency,
  });

  final String returnUri;
  final IdempotencyContext idempotency;
}
