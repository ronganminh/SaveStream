class StoreProductInfo {
  const StoreProductInfo({required this.id, required this.localizedPrice});

  final String id;

  /// Price as Google Play formats it for the user's country and currency.
  final String localizedPrice;
}

enum PurchaseEventStatus {
  purchased,
  pending,
  cancelled,
  failed,
  restored,

  /// Marker after the store answered a restore request (also when it found
  /// nothing), emitted after that batch's `restored` events.
  restoreCompleted,
}

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

  /// Google Play order id (`GPA.…`), or the purchase token when Play gives
  /// no order id (promo codes, some test purchases).
  final String? transactionId;

  /// The purchase token the server verifies with Google Play.
  final String? receipt;
  final String? errorMessage;
}

abstract interface class PurchaseService {
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids);

  /// Starts the store purchase flow. [accountReference] is sent to Google
  /// Play as the obfuscatedAccountId (SHA-256 of the user id) so the server
  /// can refuse a purchase token from another account.
  Future<void> buy(String productId, {String? accountReference});

  Future<void> restore();

  /// Finishes a purchase after the server credited it. On Google Play the
  /// pack is consumed so it can be bought again.
  Future<void> completePurchase(String transactionId);

  Stream<PurchaseServiceEvent> get purchaseEvents;
}
