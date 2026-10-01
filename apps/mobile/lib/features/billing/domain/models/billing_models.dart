enum PaymentOrderStatus {
  created('created'),
  pending('pending'),
  paid('paid'),
  failed('failed'),
  cancelled('cancelled'),
  expired('expired'),
  partiallyRefunded('partially_refunded'),
  refunded('refunded');

  const PaymentOrderStatus(this.apiValue);

  final String apiValue;

  bool get isAwaitingConfirmation =>
      this == PaymentOrderStatus.created || this == PaymentOrderStatus.pending;

  bool get isTerminal => !isAwaitingConfirmation;
}

class Money {
  const Money({required this.amountMinor, required this.currency});

  final int amountMinor;
  final String currency;
}

class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    required this.active,
  });

  final String id;
  final String name;
  final int credits;
  final Money price;
  final bool active;
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.packageId,
    required this.status,
    required this.credits,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    this.provider,
    this.providerReference,
  });

  final String id;
  final String packageId;
  final PaymentOrderStatus status;
  final int credits;
  final Money amount;
  final String? provider;
  final String? providerReference;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CheckoutSession {
  const CheckoutSession({
    required this.checkoutUri,
    required this.paymentOrder,
  });

  final Uri checkoutUri;
  final PaymentOrder paymentOrder;
}

class BillingSnapshot {
  const BillingSnapshot({required this.packages, required this.orders});

  final List<CreditPackage> packages;
  final List<PaymentOrder> orders;
}
