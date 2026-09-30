import '../models/billing_models.dart';

abstract interface class BillingRepository {
  Future<BillingSnapshot> getSnapshot();

  Future<PaymentOrder?> createPaymentOrder(String packageId);

  Future<PaymentOrder?> refreshPaymentOrder(String orderId);
}
