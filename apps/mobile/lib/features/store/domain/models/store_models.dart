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
  });

  final String id;
  final String name;
  final int cloudMinutes;
  final StoreProductIds productIds;
}

class StorePurchaseRequest {
  const StorePurchaseRequest({
    required this.platform,
    required this.productId,
    required this.transactionId,
    required this.receipt,
  });

  final StorePurchasePlatform platform;
  final String productId;
  final String transactionId;
  final String receipt;
}

enum StorePurchaseStatus { credited, pending, rejected }

class StorePurchaseResult {
  const StorePurchaseResult({
    required this.status,
    required this.paymentOrderId,
    required this.cloudMinutesAdded,
    required this.cloudMinutesAvailable,
  });

  final StorePurchaseStatus status;
  final String paymentOrderId;
  final int cloudMinutesAdded;
  final int cloudMinutesAvailable;
}
