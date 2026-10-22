import '../../../core/api/api_client.dart';
import '../domain/credit_balance.dart';

final class ApiCreditsRepository implements CreditsRepository {
  const ApiCreditsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<CreditBalance> getBalance() async {
    final response = await _apiClient.get<CreditBalance>(
      '/v1/credits/balance',
      decoder: decodeCreditBalance,
    );
    return response.data;
  }
}

CreditBalance decodeCreditBalance(Object? json) {
  if (json is! Map) throw const FormatException('Expected balance object.');
  int read(String key, {bool required = true}) {
    final Object? value = json[key];
    if (value == null && !required) return 0;
    if (value is! int) throw FormatException('Expected $key integer.');
    return value;
  }

  return CreditBalance(
    posted: read('posted'),
    reserved: read('reserved'),
    available: read('available'),
    refundDebt: read('refund_debt', required: false),
  );
}
