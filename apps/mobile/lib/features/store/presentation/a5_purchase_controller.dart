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

/// The Play Billing obfuscatedAccountId for a user: SHA-256 of the user id,
/// as the server computes it (`play_account_reference`).
String playAccountReference(String userId) =>
    sha256.convert(utf8.encode(userId)).toString();

class CloudHoursPurchaseController extends Notifier<CloudHoursPurchaseState> {
  StreamSubscription<PurchaseServiceEvent>? _subscription;

  /// Server submissions of the restore in progress.
  final List<Future<StorePurchaseResult?>> _restoreSubmissions =
      <Future<StorePurchaseResult?>>[];

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
    try {
      final String? accountReference = await _accountReference();
      await ref
          .read(purchaseServiceProvider)
          .buy(offer.productId, accountReference: accountReference);
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: offer.productId,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> restore() async {
    _restoreSubmissions.clear();
    state = const CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.restoring,
      isRestore: true,
    );
    try {
      await ref.read(purchaseServiceProvider).restore();
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        errorMessage: error.toString(),
        isRestore: true,
      );
    }
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
        state = CloudHoursPurchaseState(
          phase: CloudHoursPurchasePhase.failed,
          selectedProductId: event.productId == 'restore'
              ? null
              : event.productId,
          errorMessage: event.errorMessage,
          isRestore: event.productId == 'restore',
        );
        return;
      case PurchaseEventStatus.pending:
        state = CloudHoursPurchaseState(
          phase: CloudHoursPurchasePhase.pending,
          selectedProductId: event.productId,
          orderId: event.transactionId,
        );
        return;
      case PurchaseEventStatus.restoreCompleted:
        await _finishRestore();
        return;
      case PurchaseEventStatus.purchased:
      case PurchaseEventStatus.restored:
        break;
    }
    if (event.transactionId == null ||
        event.receipt == null ||
        event.receipt!.isEmpty) {
      return;
    }

    final DevicePlatform platform = ref
        .read(deviceInfoServiceProvider)
        .platform;
    final StorePurchaseRequest request = StorePurchaseRequest(
      platform: platform == DevicePlatform.ios
          ? StorePurchasePlatform.appStore
          : StorePurchasePlatform.googlePlay,
      productId: event.productId,
      transactionId: event.transactionId!,
      receipt: event.receipt!,
    );
    await ref.read(storePurchaseRetryStoreProvider).put(request);
    if (event.status == PurchaseEventStatus.restored) {
      final Future<StorePurchaseResult?> submission = _submit(request);
      _restoreSubmissions.add(submission);
      await submission;
      return;
    }
    await _submitPurchase(request);
  }

  Future<void> _finishRestore() async {
    final List<StorePurchaseResult?> results = await Future.wait(
      List<Future<StorePurchaseResult?>>.of(_restoreSubmissions),
    );
    _restoreSubmissions.clear();
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
  Future<StorePurchaseResult?> _submit(StorePurchaseRequest request) async {
    try {
      final StorePurchaseResult result = await ref
          .read(storeRepositoryProvider)
          .submitPurchase(request);
      if (result.status == StorePurchaseStatus.credited) {
        try {
          await ref
              .read(purchaseServiceProvider)
              .completePurchase(request.transactionId);
          await ref
              .read(storePurchaseRetryStoreProvider)
              .remove(request.transactionId);
        } on Object {
          // Keep the durable retry item. The store can redeliver unfinished
          // purchases after restart; the backend endpoint is idempotent.
        }
      }
      return result.withProductId(request.productId);
    } on Object {
      return null;
    }
  }

  Future<void> _submitPurchase(StorePurchaseRequest request) async {
    try {
      final StorePurchaseResult result = await ref
          .read(storeRepositoryProvider)
          .submitPurchase(request);

      if (result.status == StorePurchaseStatus.credited) {
        try {
          await ref
              .read(purchaseServiceProvider)
              .completePurchase(request.transactionId);
          await ref
              .read(storePurchaseRetryStoreProvider)
              .remove(request.transactionId);
        } on Object {
          // Kept for retry; see _submit.
        }

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
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: request.productId,
        errorMessage: error.toString(),
      );
    }
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
