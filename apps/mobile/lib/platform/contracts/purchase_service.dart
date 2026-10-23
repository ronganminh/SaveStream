class StoreProductInfo {
  const StoreProductInfo({
    required this.id,
    required this.localizedPrice,
    this.priceAmountMicros,
    this.currencyCode,
  });

  final String id;

  /// Price as Google Play formats it for the user's country and currency.
  final String localizedPrice;

  /// The same price in micros (24990000 = 24.99) and its ISO 4217 code.
  final int? priceAmountMicros;
  final String? currencyCode;
}

enum PurchaseEventStatus { purchased, pending, cancelled, failed }

class PurchaseServiceEvent {
  const PurchaseServiceEvent({
    required this.productId,
    required this.status,
    this.transactionId,
    this.receipt,
    this.errorMessage,
    this.alreadyOwned = false,
  });

  final String productId;
  final PurchaseEventStatus status;

  /// Google Play order id (`GPA.…`), or the purchase token when Play gives
  /// no order id (promo codes, some test purchases).
  final String? transactionId;

  /// The purchase token the server verifies with Google Play.
  final String? receipt;
  final String? errorMessage;

  /// The store refused a purchase because the account still owns an
  /// unconsumed one of this product (Play `ITEM_ALREADY_OWNED`).
  final bool alreadyOwned;
}

abstract interface class PurchaseService {
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids);

  /// Starts the store purchase flow. [accountReference] is sent to Google
  /// Play as the obfuscatedAccountId (SHA-256 of the user id) so the server
  /// can refuse a purchase token from another account.
  Future<void> buy(String productId, {String? accountReference});

  /// Purchases the store still holds unfinished, without any UI: on Google
  /// Play the in-app purchases that are bought (or pending) but not consumed
  /// (`queryPurchasesAsync`), as `purchased` or `pending` events. Each can be
  /// passed to [completePurchase] afterwards.
  Future<List<PurchaseServiceEvent>> unfinishedPurchases();

  /// Finishes a purchase after the server credited it. On Google Play the
  /// pack is consumed so it can be bought again.
  Future<void> completePurchase(String transactionId);

  Stream<PurchaseServiceEvent> get purchaseEvents;
}
