import '../models/entitlement.dart';

abstract interface class EntitlementRepository {
  Future<Entitlement> getEntitlement();
}
