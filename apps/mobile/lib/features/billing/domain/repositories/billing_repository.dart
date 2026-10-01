import '../models/billing_models.dart';

abstract interface class BillingRepository {
  Future<BillingSnapshot> getSnapshot();

  Future<PaymentOrder?> createPaymentOrder(String packageId);

  Future<CheckoutSession?> createCheckout({
    required String orderId,
    required Uri returnUri,
  });

  Future<PaymentOrder?> refreshPaymentOrder(String orderId);

  Stream<PaymentOrder?> watchPaymentOrder(String orderId);
}
