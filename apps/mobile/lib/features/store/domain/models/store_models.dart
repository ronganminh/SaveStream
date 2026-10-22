enum StorePurchasePlatform { appStore, googlePlay }

class StoreProductIds {
  const StoreProductIds({required this.appStore, required this.googlePlay});

  final String appStore;
  final String googlePlay;
}

class StorePackage {
  const StorePackage({
    required this.id,
    required this.name,
    required this.cloudMinutes,
    required this.productIds,
    this.featured = false,
  });

  final String id;
  final String name;
  final int cloudMinutes;
  final StoreProductIds productIds;

  /// `featured`: the server's "Most popular" pack.
  final bool featured;
}

class StorePurchaseRequest {
  const StorePurchaseRequest({
    required this.platform,
    required this.productId,
    required this.transactionId,
    required this.receipt,
    this.priceAmountMicros,
    this.priceCurrencyCode,
  });

  final StorePurchasePlatform platform;
  final String productId;
  final String transactionId;
  final String receipt;

  /// The price the store showed (ProductDetails), display only: the server
  /// stores it on the payment order and never uses it for accounting.
  final int? priceAmountMicros;
  final String? priceCurrencyCode;
}

enum StorePurchaseStatus { credited, pending, rejected }

class StorePurchaseResult {
  const StorePurchaseResult({
    required this.status,
    required this.paymentOrderId,
    required this.cloudMinutesAdded,
    required this.cloudMinutesAvailable,
    this.productId,
  });

  final StorePurchaseStatus status;
  final String paymentOrderId;
  final int cloudMinutesAdded;
  final int cloudMinutesAvailable;

  /// The store product the result is for (set by the app, not the server).
  final String? productId;

  StorePurchaseResult withProductId(String value) => StorePurchaseResult(
    status: status,
    paymentOrderId: paymentOrderId,
    cloudMinutesAdded: cloudMinutesAdded,
    cloudMinutesAvailable: cloudMinutesAvailable,
    productId: value,
  );
}
