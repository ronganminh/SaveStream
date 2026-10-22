import '../../../core/api/api_client.dart';
import '../domain/credit_ledger.dart';

final class ApiCreditLedgerRepository
    implements CreditLedgerRepository, RewardsRepository {
  const ApiCreditLedgerRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<CreditTransactionPage> listTransactions({
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _apiClient.get<CreditTransactionPage>(
      '/v1/credits/transactions',
      queryParameters: <String, dynamic>{'limit': limit, 'cursor': ?cursor},
      decoder: decodeCreditTransactionPage,
    );
    return response.data;
  }

  @override
  Future<List<PaymentOrder>> listPaymentOrders() async {
    final response = await _apiClient.get<List<PaymentOrder>>(
      '/v1/billing/payment-orders',
      queryParameters: <String, dynamic>{'limit': 50},
      decoder: decodePaymentOrders,
    );
    return response.data;
  }

  @override
  Future<RewardIntent> createCloudMinutesReward({
    required String deviceId,
  }) async {
    final response = await _apiClient.post<RewardIntent>(
      '/v1/rewards',
      data: <String, Object?>{
        'purpose': 'cloud_minutes',
        'device_id': deviceId,
      },
      decoder: decodeRewardIntent,
    );
    return response.data;
  }

  @override
  Future<RewardStatus> getRewardStatus(String rewardId) async {
    final response = await _apiClient.get<RewardStatus>(
      '/v1/rewards/${Uri.encodeComponent(rewardId)}',
      decoder: (Object? json) {
        final Map<Object?, Object?> map = _map(json, 'reward');
        return switch (map['status']) {
          'pending' => RewardStatus.pending,
          'valid' => RewardStatus.valid,
          'invalid' => RewardStatus.invalid,
          'expired' => RewardStatus.expired,
          final Object? value => throw FormatException(
            'Unsupported reward status: $value',
          ),
        };
      },
    );
    return response.data;
  }
}

CreditTransactionPage decodeCreditTransactionPage(Object? json) {
  final Map<Object?, Object?> map = _map(json, 'transactions');
  final Object? items = map['items'];
  if (items is! List) throw const FormatException('Expected items array.');
  final Object? pagination = map['pagination'];
  final Object? next = pagination is Map ? pagination['next_cursor'] : null;
  return CreditTransactionPage(
    items: items.map(_transaction).toList(growable: false),
    nextCursor: next is String && next.isNotEmpty ? next : null,
  );
}

CreditTransaction _transaction(Object? json) {
  final Map<Object?, Object?> map = _map(json, 'transaction');
  final Object? released = map['released_credits'];
  final Object? referenceId = map['reference_id'];
  return CreditTransaction(
    id: _string(map['id'], 'id'),
    type: switch (map['type']) {
      'grant' => CreditTransactionType.grant,
      'charge' => CreditTransactionType.charge,
      'release' => CreditTransactionType.release,
      'adjustment' => CreditTransactionType.adjustment,
      'refund' => CreditTransactionType.refund,
      final Object? value => throw FormatException(
        'Unsupported transaction type: $value',
      ),
    },
    amount: _int(map['amount'], 'amount'),
    balanceAfter: _int(map['balance_after'], 'balance_after'),
    referenceType: _string(map['reference_type'], 'reference_type'),
    referenceId: referenceId is String ? referenceId : null,
    releasedCredits: released is int ? released : null,
    createdAt: _date(map['created_at'], 'created_at'),
  );
}

List<PaymentOrder> decodePaymentOrders(Object? json) {
  final Map<Object?, Object?> map = _map(json, 'payment orders');
  final Object? items = map['items'];
  if (items is! List) throw const FormatException('Expected items array.');
  return items
      .map((Object? item) {
        final Map<Object?, Object?> order = _map(item, 'payment order');
        final Object? provider = order['provider'];
        return PaymentOrder(
          id: _string(order['id'], 'id'),
          packageId: _string(order['package_id'], 'package_id'),
          status: switch (order['status']) {
            'created' => PaymentOrderStatus.created,
            'pending' => PaymentOrderStatus.pending,
            'paid' => PaymentOrderStatus.paid,
            'failed' => PaymentOrderStatus.failed,
            'cancelled' => PaymentOrderStatus.cancelled,
            'expired' => PaymentOrderStatus.expired,
            'partially_refunded' => PaymentOrderStatus.partiallyRefunded,
            'refunded' => PaymentOrderStatus.refunded,
            final Object? value => throw FormatException(
              'Unsupported payment status: $value',
            ),
          },
          credits: _int(order['credits'], 'credits'),
          provider: provider is String ? provider : null,
          createdAt: _date(order['created_at'], 'created_at'),
        );
      })
      .toList(growable: false);
}

RewardIntent decodeRewardIntent(Object? json) {
  final Map<Object?, Object?> map = _map(json, 'reward');
  return RewardIntent(
    rewardId: _string(map['reward_id'], 'reward_id'),
    ssvUserId: _string(map['ssv_user_id'], 'ssv_user_id'),
    ssvCustomData: _string(map['ssv_custom_data'], 'ssv_custom_data'),
    expiresAt: _date(map['expires_at'], 'expires_at'),
  );
}

Map<Object?, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('Expected $name object.');
  return value;
}

String _string(Object? value, String name) {
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected $name string.');
  }
  return value;
}

int _int(Object? value, String name) {
  if (value is! int) throw FormatException('Expected $name integer.');
  return value;
}

DateTime _date(Object? value, String name) {
  final DateTime? parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('Expected $name timestamp.');
  return parsed;
}
