import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/contracts/purchase_service.dart';
import '../../../platform/platform_providers.dart';
import '../../channels/presentation/controllers/watch_providers.dart';
import '../../credits/presentation/credits_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import '../domain/models/store_models.dart';
import 'a5_store_providers.dart';

enum CloudHoursPurchasePhase {
  idle,
  processing,

  /// Google Play is still confirming the payment (Play `PENDING`, or the
  /// server answered `payment_pending`). Minutes are added when it settles.
  pending,
  credited,
  cancelled,
  failed,
  restoring,
  restored,
}

/// A pack the server credited during a restore.
class RestoredPurchase {
  const RestoredPurchase({required this.productId, required this.minutes});

  final String productId;
  final int minutes;
}

class CloudHoursPurchaseState {
  const CloudHoursPurchaseState({
    this.phase = CloudHoursPurchasePhase.idle,
    this.selectedProductId,
    this.errorMessage,
    this.isRestore = false,
    this.orderId,
    this.minutesAdded = 0,
    this.balanceAfter,
    this.restored = const <RestoredPurchase>[],
  });

  final CloudHoursPurchasePhase phase;
  final String? selectedProductId;
  final String? errorMessage;
  final bool isRestore;

  /// Google Play order id (`GPA.…`) of the purchase.
  final String? orderId;
  final int minutesAdded;

  /// Available minutes after the server credited the purchase.
  final int? balanceAfter;

  /// Packs a restore found that had not been added yet.
  final List<RestoredPurchase> restored;
}

final NotifierProvider<CloudHoursPurchaseController, CloudHoursPurchaseState>
cloudHoursPurchaseControllerProvider =
    NotifierProvider<CloudHoursPurchaseController, CloudHoursPurchaseState>(
      CloudHoursPurchaseController.new,
    );

/// Finishes purchases the store still holds (paid but never credited or
/// never consumed), once per app session; the main shell watches it, so it
/// runs after sign-in.
final FutureProvider<void> purchaseRecoveryProvider = FutureProvider<void>(
  (Ref ref) =>
      ref.read(cloudHoursPurchaseControllerProvider.notifier).recoverOnStart(),
);

/// The Play Billing obfuscatedAccountId for a user: SHA-256 of the user id,
/// as the server computes it (`play_account_reference`).
String playAccountReference(String userId) =>
    sha256.convert(utf8.encode(userId)).toString();

class CloudHoursPurchaseController extends Notifier<CloudHoursPurchaseState> {
  StreamSubscription<PurchaseServiceEvent>? _subscription;

  /// Server submissions in flight by transaction id, so a purchase found by
  /// several paths at once (store stream, recovery, retry queue) is sent once.
  final Map<String, Future<StorePurchaseResult?>> _inFlight =
      <String, Future<StorePurchaseResult?>>{};
  bool _recoveredOnStart = false;

  @override
  CloudHoursPurchaseState build() {
    _subscription = ref
        .watch(purchaseServiceProvider)
        .purchaseEvents
        .listen(_handlePurchaseEvent);
    ref.onDispose(() => _subscription?.cancel());
    Future<void>.microtask(_retryPendingPurchases);
    return const CloudHoursPurchaseState();
  }

  Future<void> buy(CloudHoursOffer offer) async {
    state = CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.processing,
      selectedProductId: offer.productId,
    );
    // Play refuses to sell a pack the account still owns unconsumed ("You
    // already own this item"): finish that purchase instead.
    if (await _finishOwned(offer.productId)) return;
    try {
      final String? accountReference = await _accountReference();
      await ref
          .read(purchaseServiceProvider)
          .buy(offer.productId, accountReference: accountReference);
    } on Object catch (error) {
      if (await _finishOwned(offer.productId)) return;
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: offer.productId,
        errorMessage: error.toString(),
      );
    }
  }

  /// "Restore purchases": sends every purchase the store still holds
  /// unfinished to the server and reports the packs it added.
  Future<void> restore() async {
    state = const CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.restoring,
      isRestore: true,
    );
    final List<StorePurchaseResult?> results;
    try {
      results = await _recoverUnfinished();
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        errorMessage: error.toString(),
        isRestore: true,
      );
      return;
    }
    if (results.isNotEmpty && results.every((r) => r == null)) {
      state = const CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        isRestore: true,
      );
      return;
    }
    final List<RestoredPurchase> added = <RestoredPurchase>[
      for (final StorePurchaseResult? result in results)
        if (result != null &&
            result.status == StorePurchaseStatus.credited &&
            result.cloudMinutesAdded > 0)
          RestoredPurchase(
            productId: result.productId ?? '',
            minutes: result.cloudMinutesAdded,
          ),
    ];
    if (added.isNotEmpty) _refreshPurchasedData();
    state = CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.restored,
      isRestore: true,
      restored: added,
    );
  }

  /// Once per app session, after sign-in: finish purchases the store still
  /// holds (the app was closed, offline or the server refused it before).
  /// Silent; balances refresh when something was added.
  Future<void> recoverOnStart() async {
    if (_recoveredOnStart) return;
    _recoveredOnStart = true;
    try {
      final List<StorePurchaseResult?> results = await _recoverUnfinished();
      if (results.any(
        (StorePurchaseResult? r) => r?.status == StorePurchaseStatus.credited,
      )) {
        _refreshPurchasedData();
      }
    } on Object {
      // The store or the server is unreachable; the next start tries again.
    }
  }

  /// Sends each purchase the store holds unfinished to the server, which
  /// verifies it with Google Play and credits it once per purchase token;
  /// only a credited purchase is then consumed. Pending ones are sent too,
  /// so the server credits them when Play settles the payment. Null results
  /// are submissions that failed (kept in the retry queue).
  Future<List<StorePurchaseResult?>> _recoverUnfinished() async {
    final List<PurchaseServiceEvent> unfinished = await ref
        .read(purchaseServiceProvider)
        .unfinishedPurchases();
    final List<StorePurchaseResult?> results = <StorePurchaseResult?>[];
    for (final PurchaseServiceEvent event in unfinished) {
      final StorePurchaseRequest? request = _requestFor(event);
      if (request == null) continue;
      await ref.read(storePurchaseRetryStoreProvider).put(request);
      results.add(await _submit(request));
    }
    return results;
  }

  /// When the store still holds an unfinished purchase of [productId],
  /// finishes it with the purchase UI states and returns true.
  Future<bool> _finishOwned(String productId) async {
    final List<PurchaseServiceEvent> unfinished;
    try {
      unfinished = await ref
          .read(purchaseServiceProvider)
          .unfinishedPurchases();
    } on Object {
      return false;
    }
    for (final PurchaseServiceEvent event in unfinished) {
      if (event.productId != productId) continue;
      final StorePurchaseRequest? request = _requestFor(event);
      if (request == null) continue;
      await ref.read(storePurchaseRetryStoreProvider).put(request);
      await _submitPurchase(request);
      return true;
    }
    return false;
  }

  /// Back to idle after a result was shown (dialog closed, Done pressed).
  void acknowledge() {
    state = const CloudHoursPurchaseState();
  }

  Future<String?> _accountReference() async {
    try {
      final UserProfile profile = await ref.read(profileProvider.future);
      final String? id = profile.id;
      return id == null ? null : playAccountReference(id);
    } on Object {
      // The server rejects an unlinked purchase when it requires the link.
      return null;
    }
  }

  Future<void> _handlePurchaseEvent(PurchaseServiceEvent event) async {
    switch (event.status) {
      case PurchaseEventStatus.cancelled:
        state = const CloudHoursPurchaseState(
          phase: CloudHoursPurchasePhase.cancelled,
        );
        return;
      case PurchaseEventStatus.failed:
        final String? productId = event.productId.isEmpty
            ? state.selectedProductId
            : event.productId;
        if (event.alreadyOwned &&
            productId != null &&
            await _finishOwned(productId)) {
          return;
        }
        state = CloudHoursPurchaseState(
          phase: CloudHoursPurchasePhase.failed,
          selectedProductId: productId,
          errorMessage: event.errorMessage,
        );
        return;
      case PurchaseEventStatus.pending:
        state = CloudHoursPurchaseState(
          phase: CloudHoursPurchasePhase.pending,
          selectedProductId: event.productId,
          orderId: event.transactionId,
        );
        return;
      case PurchaseEventStatus.purchased:
        break;
    }
    final StorePurchaseRequest? request = _requestFor(event);
    if (request == null) return;
    await ref.read(storePurchaseRetryStoreProvider).put(request);
    await _submitPurchase(request);
  }

  /// The server request for a purchased (or pending) store event; null when
  /// the store gave no transaction or token.
  StorePurchaseRequest? _requestFor(PurchaseServiceEvent event) {
    if (event.transactionId == null ||
        event.receipt == null ||
        event.receipt!.isEmpty) {
      return null;
    }
    final DevicePlatform platform = ref
        .read(deviceInfoServiceProvider)
        .platform;
    // The price Play showed for this product, sent for display only.
    CloudHoursOffer? offer;
    for (final CloudHoursOffer item
        in ref.read(cloudHoursOffersProvider).value ??
            const <CloudHoursOffer>[]) {
      if (item.productId == event.productId) offer = item;
    }
    return StorePurchaseRequest(
      platform: platform == DevicePlatform.ios
          ? StorePurchasePlatform.appStore
          : StorePurchasePlatform.googlePlay,
      productId: event.productId,
      transactionId: event.transactionId!,
      receipt: event.receipt!,
      priceAmountMicros: offer?.priceAmountMicros,
      priceCurrencyCode: offer?.currencyCode,
    );
  }

  Future<void> _retryPendingPurchases() async {
    final List<StorePurchaseRequest> pending = await ref
        .read(storePurchaseRetryStoreProvider)
        .load();
    for (final StorePurchaseRequest request in pending) {
      final StorePurchaseResult? result = await _submit(request);
      if (result?.status == StorePurchaseStatus.credited) {
        _refreshPurchasedData();
      }
    }
  }

  /// Sends the purchase to the server; finishes it with the store once the
  /// server credited it. Null when the request failed (kept for retry).
  Future<StorePurchaseResult?> _submit(StorePurchaseRequest request) {
    final String key = request.transactionId;
    final Future<StorePurchaseResult?>? running = _inFlight[key];
    if (running != null) return running;
    final Future<StorePurchaseResult?> submission = _send(request).whenComplete(
      () {
        // A block, not `=> _inFlight.remove(key)`: returning the removed
        // future would make the submission wait for itself.
        _inFlight.remove(key);
      },
    );
    _inFlight[key] = submission;
    return submission;
  }

  Future<StorePurchaseResult?> _send(StorePurchaseRequest request) async {
    try {
      final StorePurchaseResult result = await ref
          .read(storeRepositoryProvider)
          .submitPurchase(request);
      if (result.status == StorePurchaseStatus.credited) {
        // Credited (now or before: the endpoint is idempotent per purchase
        // token), so the queued request is done.
        await ref
            .read(storePurchaseRetryStoreProvider)
            .remove(request.transactionId);
        try {
          // Consume only now, after the server confirmed. The server
          // consumes too; if both fail, the next start finds the purchase
          // with unfinishedPurchases() and finishes it.
          await ref
              .read(purchaseServiceProvider)
              .completePurchase(request.transactionId);
        } on Object {
          // See above.
        }
      }
      return result.withProductId(request.productId);
    } on Object {
      return null;
    }
  }

  Future<void> _submitPurchase(StorePurchaseRequest request) async {
    final StorePurchaseResult? result = await _submit(request);
    if (result == null) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: request.productId,
        orderId: request.transactionId,
      );
      return;
    }
    if (result.status == StorePurchaseStatus.credited) {
      _refreshPurchasedData();
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.credited,
        selectedProductId: request.productId,
        orderId: request.transactionId,
        minutesAdded: result.cloudMinutesAdded,
        balanceAfter: result.cloudMinutesAvailable,
      );
      return;
    }
    state = CloudHoursPurchaseState(
      phase: result.status == StorePurchaseStatus.pending
          ? CloudHoursPurchasePhase.pending
          : CloudHoursPurchasePhase.failed,
      selectedProductId: request.productId,
      orderId: request.transactionId,
      errorMessage: result.status == StorePurchaseStatus.rejected
          ? 'Store receipt was rejected.'
          : null,
    );
  }

  void _refreshPurchasedData() {
    ref.invalidate(entitlementProvider);
    ref.invalidate(creditBalanceProvider);
    ref.invalidate(creditTransactionsProvider);
    ref.invalidate(playPurchasesProvider);
    ref.invalidate(watchListProvider);
    ref.invalidate(homeDashboardProvider);
    ref.read(watchRevisionProvider.notifier).bump();
  }
}
