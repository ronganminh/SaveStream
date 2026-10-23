import 'dart:async';

import '../contracts/purchase_service.dart';

/// Store stand-in for mock builds and tests: no real purchase is made.
final class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    Map<String, String>? prices,
    this.buyStatus = PurchaseEventStatus.purchased,
    this.restorable = const <String>[],
  }) : prices = prices ?? defaultPrices;

  /// Display prices for previews; real builds always read them from Play.
  static const Map<String, String> defaultPrices = <String, String>{
    'savestream.hours.50': r'$9.99',
    'savestream.hours.150': r'$24.99',
    'savestream.hours.400': r'$59.99',
  };

  final Map<String, String> prices;

  /// What the store answers to [buy].
  PurchaseEventStatus buyStatus;

  /// Product ids the store still holds unfinished (bought, not consumed),
  /// as [unfinishedPurchases] reports them. Completing one consumes it.
  List<String> restorable;

  /// Of [restorable], the ones whose payment is still pending.
  Set<String> pendingUnfinished = <String>{};

  final List<String> purchases = <String>[];
  final List<String?> accountReferences = <String?>[];
  final List<String> completedTransactions = <String>[];

  final StreamController<PurchaseServiceEvent> _events =
      StreamController<PurchaseServiceEvent>.broadcast();

  @override
  Stream<PurchaseServiceEvent> get purchaseEvents => _events.stream;

  void emit(PurchaseServiceEvent event) => _events.add(event);

  @override
  Future<List<StoreProductInfo>> loadProducts(Iterable<String> ids) async {
    return ids
        .where(prices.containsKey)
        .map(
          (String id) => StoreProductInfo(
            id: id,
            localizedPrice: prices[id]!,
            priceAmountMicros: _micros(prices[id]!),
            currencyCode: prices[id]!.startsWith(r'$') ? 'USD' : null,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> buy(String productId, {String? accountReference}) async {
    purchases.add(productId);
    accountReferences.add(accountReference);
    final bool settled =
        buyStatus == PurchaseEventStatus.purchased ||
        buyStatus == PurchaseEventStatus.pending;
    _events.add(
      PurchaseServiceEvent(
        productId: productId,
        status: buyStatus,
        transactionId: settled ? 'GPA.0000-${purchases.length}' : null,
        receipt: settled ? 'fake-token-$productId' : null,
        errorMessage: buyStatus == PurchaseEventStatus.failed
            ? 'BillingResponse.error'
            : null,
      ),
    );
  }

  @override
  Future<void> completePurchase(String transactionId) async {
    completedTransactions.add(transactionId);
    restorable = <String>[
      for (final String id in restorable)
        if (transactionId != 'GPA.restored-$id') id,
    ];
  }

  @override
  Future<List<PurchaseServiceEvent>> unfinishedPurchases() async {
    return <PurchaseServiceEvent>[
      for (final String id in restorable)
        PurchaseServiceEvent(
          productId: id,
          status: pendingUnfinished.contains(id)
              ? PurchaseEventStatus.pending
              : PurchaseEventStatus.purchased,
          transactionId: 'GPA.restored-$id',
          receipt: 'fake-token-$id',
        ),
    ];
  }

  Future<void> dispose() => _events.close();

  /// "$24.99" → 24990000 (null when the preview price has no number).
  static int? _micros(String price) {
    final double? value = double.tryParse(
      price.replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    return value == null ? null : (value * 1000000).round();
  }
}
