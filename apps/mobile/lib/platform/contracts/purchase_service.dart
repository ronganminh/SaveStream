class StoreProductInfo {
  const StoreProductInfo({
    required this.id,
    required this.localizedPrice,
  });

  final String id;
  final String localizedPrice;
}

enum PurchaseEventStatus { purchased, pending, cancelled, failed, restored }

class PurchaseServiceEvent {
  const PurchaseServiceEvent({
    required this.productId,
    required this.status,
    this.transactionId,
    this.receipt,
    this.errorMessage,
  });

  final String productId;
  final PurchaseEventStatus status;
  final String? transactionId;
  final String? receipt;
  final String? errorMessage;
}

abstract interface class PurchaseService {
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids);

  Future<void> buy(String productId);

  Future<void> restore();

  Stream<PurchaseServiceEvent> get purchaseEvents;
}
