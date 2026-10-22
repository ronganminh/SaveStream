import '../../../core/mock/mock_repository_base.dart';
import '../domain/credit_balance.dart';

final class MockCreditsRepository extends MockRepositoryBase
    implements CreditsRepository {
  const MockCreditsRepository(super.behavior, {this.balance = _default});

  static const CreditBalance _default = CreditBalance(
    posted: 0,
    reserved: 0,
    available: 0,
  );

  final CreditBalance balance;

  @override
  Future<CreditBalance> getBalance() {
    return respond<CreditBalance>(success: () => balance, empty: () => balance);
  }
}
