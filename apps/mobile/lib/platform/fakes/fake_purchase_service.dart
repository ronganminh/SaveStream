import 'dart:async';

import '../contracts/purchase_service.dart';

final class FakePurchaseService implements PurchaseService {
  final StreamController<PurchaseServiceEvent> _events =
      StreamController<PurchaseServiceEvent>.broadcast();

  @override
  Stream<PurchaseServiceEvent> get purchaseEvents => _events.stream;

  @override
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids) async {
    return ids.map((String id) {
      final String price = switch (id) {
        'savestream.hours.50' => r'$9.99',
        'savestream.hours.150' => r'$24.99',
        'savestream.hours.400' => r'$59.99',
        _ => r'$0.00',
      };
      return StoreProductInfo(id: id, localizedPrice: price);
    }).toList(growable: false);
  }

  @override
  Future<void> buy(String productId) async {
    _events.add(PurchaseServiceEvent(
      productId: productId,
      status: PurchaseEventStatus.purchased,
      transactionId: 'txn_fake_$productId',
      receipt: 'fake-receipt-$productId',
    ));
  }

  @override
  Future<void> restore() async {
    _events.add(const PurchaseServiceEvent(
      productId: 'restore',
      status: PurchaseEventStatus.restored,
    ));
  }
}
