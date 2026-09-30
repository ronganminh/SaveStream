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
      credits: 10,
      price: 4.99,
      currency: 'USD',
    ),
    CreditPackage(
      id: 'pkg_25',
      credits: 25,
      price: 9.99,
      currency: 'USD',
      recommended: true,
    ),
    CreditPackage(
      id: 'pkg_60',
      credits: 60,
      price: 19.99,
      currency: 'USD',
    ),
  ];

  static final List<PaymentOrder> _seedOrders = <PaymentOrder>[
    PaymentOrder(
      id: 'order_paid',
      package: _packages[1],
      status: PaymentOrderStatus.paid,
      createdAt: DateTime.utc(2026, 9, 28, 15, 2),
    ),
    PaymentOrder(
      id: 'order_failed',
      package: _packages[0],
      status: PaymentOrderStatus.failed,
      createdAt: DateTime.utc(2026, 9, 20, 9, 15),
    ),
    PaymentOrder(
      id: 'order_expired',
      package: _packages[0],
      status: PaymentOrderStatus.expired,
      createdAt: DateTime.utc(2026, 9, 12, 7, 30),
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
        if (package == null) {
          return null;
        }

        final PaymentOrder order = PaymentOrder(
          id: 'order_mock_${_nextOrder++}',
          package: package,
          status: PaymentOrderStatus.pending,
          createdAt: DateTime.now().toUtc(),
        );
        _orders.insert(0, order);
        return order;
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
        if (index < 0) {
          return null;
        }

        final PaymentOrder current = _orders[index];
        final PaymentOrder refreshed =
            current.status == PaymentOrderStatus.pending
            ? current.copyWith(status: PaymentOrderStatus.paid)
            : current;
        _orders[index] = refreshed;
        return refreshed;
      },
      empty: () => null,
    );
  }

  CreditPackage? _findPackage(String id) {
    for (final CreditPackage package in _packages) {
      if (package.id == id) {
        return package;
      }
    }
    return null;
  }
}
