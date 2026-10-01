import '../models/credit_models.dart';

abstract interface class CreditsRepository {
  Future<CreditBalance> getBalance();

  Future<CreditsOverview> getOverview();
}
