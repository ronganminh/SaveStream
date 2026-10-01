import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../domain/models/credit_models.dart';
import '../../domain/repositories/credits_repository.dart';
import '../remote/credit_api_models.dart';

final class ApiCreditsRepository implements CreditsRepository {
  const ApiCreditsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  static const int _pageSize = 100;

  final ApiClient _apiClient;

  @override
  Future<CreditBalance> getBalance() async {
    final response = await _apiClient.get<CreditBalance>(
      '/v1/credits/balance',
      decoder: creditBalanceFromJson,
    );
    return response.data;
  }

  @override
  Future<CreditsOverview> getOverview() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      getBalance(),
      _listTransactions(),
      _listReservations(),
      _getPricing(),
    ]);

    return CreditsOverview(
      balance: results[0]! as CreditBalance,
      transactions: results[1]! as List<CreditTransaction>,
      reservations: results[2]! as List<CreditReservation>,
      pricing: results[3] as PricingSnapshot?,
    );
  }

  Future<List<CreditTransaction>> _listTransactions() async {
    final List<CreditTransaction> items = <CreditTransaction>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final response = await _apiClient.get<CreditApiPage<CreditTransaction>>(
        '/v1/credits/transactions',
        queryParameters: <String, dynamic>{
          'limit': _pageSize,
          if (cursor != null) 'cursor': cursor,
        },
        decoder: creditTransactionsFromJson,
      );
      final CreditApiPage<CreditTransaction> page = response.data;
      items.addAll(page.items);
      if (!page.hasMore) {
        return List<CreditTransaction>.unmodifiable(items);
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

  Future<List<CreditReservation>> _listReservations() async {
    final List<CreditReservation> items = <CreditReservation>[];
    final Set<String> seenCursors = <String>{};
    String? cursor;

    while (true) {
      final response = await _apiClient.get<CreditApiPage<CreditReservation>>(
        '/v1/credits/reservations',
        queryParameters: <String, dynamic>{
          'limit': _pageSize,
          if (cursor != null) 'cursor': cursor,
        },
        decoder: creditReservationsFromJson,
      );
      final CreditApiPage<CreditReservation> page = response.data;
      items.addAll(page.items);
      if (!page.hasMore) {
        return List<CreditReservation>.unmodifiable(items);
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

  Future<PricingSnapshot?> _getPricing() async {
    try {
      final response = await _apiClient.get<PricingSnapshot>(
        '/v1/pricing',
        decoder: pricingFromJson,
      );
      return response.data;
    } on ApiException catch (error) {
      if (error.code == 'SERVICE_UNAVAILABLE' && error.statusCode == 503) {
        return null;
      }
      rethrow;
    }
  }
}
