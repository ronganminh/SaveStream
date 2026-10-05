import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'contracts/purchase_service.dart';

final class InAppPurchaseService implements PurchaseService {
  InAppPurchaseService({InAppPurchase? client})
    : _client = client ?? InAppPurchase.instance {
    _subscription = _client.purchaseStream.listen(
      _handlePurchases,
      onError: _handleStreamError,
    );
  }

  final InAppPurchase _client;
  final StreamController<PurchaseServiceEvent> _events =
      StreamController<PurchaseServiceEvent>.broadcast();
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  final Map<String, PurchaseDetails> _purchasesByTransaction =
      <String, PurchaseDetails>{};
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  Stream<PurchaseServiceEvent> get purchaseEvents => _events.stream;

  @override
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids) async {
    final Set<String> requested = ids.toSet();
    if (requested.isEmpty) {
      return const <StoreProductInfo>[];
    }

    final ProductDetailsResponse response = await _client.queryProductDetails(
      requested,
    );
    if (response.error != null) {
      throw StateError(response.error!.message);
    }

    _products
      ..clear()
      ..addEntries(
        response.productDetails.map(
          (ProductDetails product) =>
              MapEntry<String, ProductDetails>(product.id, product),
        ),
      );

    return response.productDetails
        .map(
          (ProductDetails product) =>
              StoreProductInfo(id: product.id, localizedPrice: product.price),
        )
        .toList(growable: false);
  }

  @override
  Future<void> buy(String productId) async {
    final ProductDetails? product = _products[productId];
    if (product == null) {
      throw StateError(
        'Product $productId must be loaded before starting a purchase.',
      );
    }
    final bool started = await _client.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
      autoConsume: false,
    );
    if (!started) {
      throw StateError('Store rejected the purchase request for $productId.');
    }
  }

  @override
  Future<void> restore() => _client.restorePurchases();

  @override
  Future<void> completePurchase(String transactionId) async {
    final PurchaseDetails? purchase = _purchasesByTransaction[transactionId];
    if (purchase == null) {
      throw StateError(
        'No store purchase details are available for $transactionId.',
      );
    }
    if (purchase.pendingCompletePurchase) {
      await _client.completePurchase(purchase);
    }
    _purchasesByTransaction.remove(transactionId);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _events.close();
  }

  void _handlePurchases(List<PurchaseDetails> purchases) {
    for (final PurchaseDetails purchase in purchases) {
      final String? transactionId = purchase.purchaseID;
      if (transactionId != null && transactionId.isNotEmpty) {
        _purchasesByTransaction[transactionId] = purchase;
      }

      final PurchaseEventStatus status = switch (purchase.status) {
        PurchaseStatus.purchased => PurchaseEventStatus.purchased,
        PurchaseStatus.pending => PurchaseEventStatus.pending,
        PurchaseStatus.canceled => PurchaseEventStatus.cancelled,
        PurchaseStatus.error => PurchaseEventStatus.failed,
        PurchaseStatus.restored => PurchaseEventStatus.restored,
      };

      _events.add(
        PurchaseServiceEvent(
          productId: purchase.productID,
          status: status,
          transactionId: transactionId,
          receipt: purchase.verificationData.serverVerificationData,
          errorMessage: purchase.error?.message,
        ),
      );
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    _events.add(
      PurchaseServiceEvent(
        productId: 'store',
        status: PurchaseEventStatus.failed,
        errorMessage: error.toString(),
      ),
    );
  }
}
