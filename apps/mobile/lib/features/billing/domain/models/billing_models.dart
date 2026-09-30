enum PaymentOrderStatus {
  pending,
  paid,
  failed,
  cancelled,
  expired,
}

class CreditPackage {
  const CreditPackage({
    required this.id,
    required this.credits,
    required this.price,
    required this.currency,
    this.recommended = false,
  });

  final String id;
  final double credits;
  final double price;
  final String currency;
  final bool recommended;
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.package,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final CreditPackage package;
  final PaymentOrderStatus status;
  final DateTime createdAt;

  PaymentOrder copyWith({PaymentOrderStatus? status}) {
    return PaymentOrder(
      id: id,
      package: package,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class BillingSnapshot {
  const BillingSnapshot({
    required this.packages,
    required this.orders,
  });

  final List<CreditPackage> packages;
  final List<PaymentOrder> orders;
}
