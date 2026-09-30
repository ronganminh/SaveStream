import '../models/credit_models.dart';

abstract interface class CreditsRepository {
  Future<CreditsOverview> getOverview();
}
