import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/billing_models.dart';
import '../../domain/repositories/billing_repository.dart';

final class MockBillingRepository extends MockRepositoryBase
    implements BillingRepository {
  MockBillingRepository(super.behavior)
    : _orders = List<PaymentOrder>.of(_seedOrders);

  static const List<CreditPackage> _packages = <CreditPackage>[
    CreditPackage(
      id: 'pkg_10',
      name: 'Starter',
      credits: 10,
      price: Money(amountMinor: 499, currency: 'USD'),
      active: true,
    ),
    CreditPackage(
      id: 'pkg_25',
      name: 'Plus',
      credits: 25,
      price: Money(amountMinor: 999, currency: 'USD'),
      active: true,
    ),
    CreditPackage(
      id: 'pkg_60',
      name: 'Pro',
      credits: 60,
      price: Money(amountMinor: 1999, currency: 'USD'),
      active: true,
    ),
  ];

  static final List<PaymentOrder> _seedOrders = <PaymentOrder>[
    PaymentOrder(
      id: 'order_paid',
      packageId: 'pkg_25',
      status: PaymentOrderStatus.paid,
      credits: 25,
      amount: const Money(amountMinor: 999, currency: 'USD'),
      provider: 'mock',
      providerReference: 'provider_paid',
      createdAt: DateTime.utc(2026, 9, 28, 15, 2),
      updatedAt: DateTime.utc(2026, 9, 28, 15, 3),
    ),
    PaymentOrder(
      id: 'order_failed',
      packageId: 'pkg_10',
      status: PaymentOrderStatus.failed,
      credits: 10,
      amount: const Money(amountMinor: 499, currency: 'USD'),
      createdAt: DateTime.utc(2026, 9, 20, 9, 15),
      updatedAt: DateTime.utc(2026, 9, 20, 9, 20),
    ),
  ];

  final List<PaymentOrder> _orders;
  int _nextOrder = 1;

  @override
  Future<BillingSnapshot> getSnapshot() {
    return respond<BillingSnapshot>(
      success: () => BillingSnapshot(
        packages: _packages,
        orders: List<PaymentOrder>.unmodifiable(_orders),
      ),
      empty: () => const BillingSnapshot(
        packages: <CreditPackage>[],
        orders: <PaymentOrder>[],
      ),
    );
  }

  @override
  Future<PaymentOrder?> createPaymentOrder(String packageId) {
    return respond<PaymentOrder?>(
      success: () {
        final CreditPackage? package = _findPackage(packageId);
        if (package == null) return null;

        final DateTime now = DateTime.now().toUtc();
        final PaymentOrder order = PaymentOrder(
          id: 'order_mock_${_nextOrder++}',
          packageId: package.id,
          status: PaymentOrderStatus.created,
          credits: package.credits,
          amount: package.price,
          createdAt: now,
          updatedAt: now,
        );
        _orders.insert(0, order);
        return order;
      },
      empty: () => null,
    );
  }

  @override
  Future<CheckoutSession?> createCheckout({
    required String orderId,
    required Uri returnUri,
  }) {
    return respond<CheckoutSession?>(
      success: () {
        final int index = _orders.indexWhere(
          (PaymentOrder order) => order.id == orderId,
        );
        if (index < 0) return null;
        final PaymentOrder current = _orders[index];
        final PaymentOrder pending = _copyOrder(
          current,
          status: PaymentOrderStatus.pending,
          provider: 'mock',
          providerReference: 'provider_$orderId',
        );
        _orders[index] = pending;
        return CheckoutSession(
          checkoutUri: Uri.parse('https://example.com/checkout/$orderId'),
          paymentOrder: pending,
        );
      },
      empty: () => null,
    );
  }

  @override
  Future<PaymentOrder?> refreshPaymentOrder(String orderId) {
    return respond<PaymentOrder?>(
      success: () {
        final int index = _orders.indexWhere(
          (PaymentOrder order) => order.id == orderId,
        );
        if (index < 0) return null;
        final PaymentOrder current = _orders[index];
        final PaymentOrder refreshed =
            current.status == PaymentOrderStatus.pending
            ? _copyOrder(current, status: PaymentOrderStatus.paid)
            : current;
        _orders[index] = refreshed;
        return refreshed;
      },
      empty: () => null,
    );
  }

  @override
  Stream<PaymentOrder?> watchPaymentOrder(String orderId) async* {
    yield await refreshPaymentOrder(orderId);
  }

  CreditPackage? _findPackage(String id) {
    for (final CreditPackage package in _packages) {
      if (package.id == id) return package;
    }
    return null;
  }

  PaymentOrder _copyOrder(
    PaymentOrder order, {
    required PaymentOrderStatus status,
    String? provider,
    String? providerReference,
  }) {
    return PaymentOrder(
      id: order.id,
      packageId: order.packageId,
      status: status,
      credits: order.credits,
      amount: order.amount,
      provider: provider ?? order.provider,
      providerReference: providerReference ?? order.providerReference,
      createdAt: order.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
