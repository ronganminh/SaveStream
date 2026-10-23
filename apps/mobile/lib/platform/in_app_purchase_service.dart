import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

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
          (ProductDetails product) => StoreProductInfo(
            id: product.id,
            localizedPrice: product.price,
            // On Android rawPrice is Play's priceAmountMicros / 1e6.
            priceAmountMicros: (product.rawPrice * 1000000).round(),
            currencyCode: product.currencyCode.isEmpty
                ? null
                : product.currencyCode,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> buy(String productId, {String? accountReference}) async {
    final ProductDetails? product = _products[productId];
    if (product == null) {
      throw StateError(
        'Product $productId must be loaded before starting a purchase.',
      );
    }
    final bool started = await _client.buyConsumable(
      // applicationUserName is Play Billing's obfuscatedAccountId.
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: accountReference,
      ),
      autoConsume: false,
    );
    if (!started) {
      throw StateError('Store rejected the purchase request for $productId.');
    }
  }

  @override
  Future<List<PurchaseServiceEvent>> unfinishedPurchases() async {
    if (!Platform.isAndroid) {
      return const <PurchaseServiceEvent>[];
    }
    // queryPurchasesAsync: what the account owns and has not consumed. A pack
    // is consumed only after the server credited it, so anything here was
    // paid (or is still pending) but never credited or never finished.
    final QueryPurchaseDetailsResponse response = await _client
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryPastPurchases();
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    return <PurchaseServiceEvent>[
      for (final GooglePlayPurchaseDetails purchase in response.pastPurchases)
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.pending)
          _eventFor(
            purchase,
            purchase.status == PurchaseStatus.pending
                ? PurchaseEventStatus.pending
                : PurchaseEventStatus.purchased,
          ),
    ];
  }

  @override
  Future<void> completePurchase(String transactionId) async {
    final PurchaseDetails? purchase = _purchasesByTransaction[transactionId];
    if (purchase == null) {
      throw StateError(
        'No store purchase details are available for $transactionId.',
      );
    }
    if (purchase is GooglePlayPurchaseDetails) {
      // The server consumes too; consuming here as well makes the pack
      // buyable again at once. Consuming implies acknowledging, so a failure
      // (e.g. already consumed by the server) falls back to acknowledge.
      final BillingResultWrapper result = await _client
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
          .consumePurchase(purchase);
      if (result.responseCode != BillingResponse.ok &&
          purchase.pendingCompletePurchase) {
        await _client.completePurchase(purchase);
      }
    } else if (purchase.pendingCompletePurchase) {
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
      final PurchaseEventStatus status = switch (purchase.status) {
        PurchaseStatus.purchased => PurchaseEventStatus.purchased,
        PurchaseStatus.pending => PurchaseEventStatus.pending,
        PurchaseStatus.canceled => PurchaseEventStatus.cancelled,
        PurchaseStatus.error => PurchaseEventStatus.failed,
        // Only restorePurchases() reports this, and the app never calls it
        // (it uses unfinishedPurchases()).
        PurchaseStatus.restored => PurchaseEventStatus.purchased,
      };
      _events.add(_eventFor(purchase, status));
    }
  }

  /// The event for [purchase]; remembers it for [completePurchase].
  PurchaseServiceEvent _eventFor(
    PurchaseDetails purchase,
    PurchaseEventStatus status,
  ) {
    final String token = purchase.verificationData.serverVerificationData;
    final String? orderId = purchase.purchaseID;
    // Play leaves orderId empty for promo codes; the server then accepts
    // the purchase token as the transaction id.
    final String? transactionId = orderId != null && orderId.isNotEmpty
        ? orderId
        : (token.isEmpty ? null : token);
    if (transactionId != null && transactionId.isNotEmpty) {
      _purchasesByTransaction[transactionId] = purchase;
    }
    return PurchaseServiceEvent(
      productId: purchase.productID,
      status: status,
      transactionId: transactionId,
      receipt: token,
      errorMessage: purchase.error?.message,
      alreadyOwned:
          purchase.error?.message ==
          BillingResponse.itemAlreadyOwned.toString(),
    );
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
