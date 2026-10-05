import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/contracts/purchase_service.dart';
import '../../../platform/platform_providers.dart';
import '../../channels/presentation/controllers/watch_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/store_models.dart';
import 'a5_store_providers.dart';

enum CloudHoursPurchasePhase {
  idle,
  processing,
  pending,
  credited,
  cancelled,
  failed,
  restoring,
  restored,
}

enum CloudHoursPurchaseContext {
  autoRecord,
  watchLimit,
  iosBackground,
  freeMinutesExhausted,
  removeAds,
}

class CloudHoursPurchaseState {
  const CloudHoursPurchaseState({
    this.phase = CloudHoursPurchasePhase.idle,
    this.selectedProductId,
    this.errorMessage,
    this.isRestore = false,
  });

  final CloudHoursPurchasePhase phase;
  final String? selectedProductId;
  final String? errorMessage;
  final bool isRestore;
}

final NotifierProvider<CloudHoursPurchaseController, CloudHoursPurchaseState>
cloudHoursPurchaseControllerProvider =
    NotifierProvider<CloudHoursPurchaseController, CloudHoursPurchaseState>(
      CloudHoursPurchaseController.new,
    );

class CloudHoursPurchaseController extends Notifier<CloudHoursPurchaseState> {
  StreamSubscription<PurchaseServiceEvent>? _subscription;

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
      await ref.read(purchaseServiceProvider).buy(offer.productId);
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: offer.productId,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> restore() async {
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

  Future<void> _handlePurchaseEvent(PurchaseServiceEvent event) async {
    if (event.status == PurchaseEventStatus.cancelled) {
      state = const CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.cancelled,
      );
      return;
    }
    if (event.status == PurchaseEventStatus.failed) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: event.productId == 'restore'
            ? null
            : event.productId,
        errorMessage: event.errorMessage,
        isRestore: event.productId == 'restore',
      );
      return;
    }
    if (event.status == PurchaseEventStatus.pending) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.pending,
        selectedProductId: event.productId,
      );
      return;
    }
    if ((event.status != PurchaseEventStatus.purchased &&
            event.status != PurchaseEventStatus.restored) ||
        event.transactionId == null ||
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
    await _submitPurchase(
      request,
      restored: event.status == PurchaseEventStatus.restored,
    );
  }

  Future<void> _retryPendingPurchases() async {
    final List<StorePurchaseRequest> pending = await ref
        .read(storePurchaseRetryStoreProvider)
        .load();
    for (final StorePurchaseRequest request in pending) {
      await _submitPurchase(request);
    }
  }

  Future<void> _submitPurchase(
    StorePurchaseRequest request, {
    bool restored = false,
  }) async {
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

        _refreshPurchasedData();
        state = CloudHoursPurchaseState(
          phase: restored
              ? CloudHoursPurchasePhase.restored
              : CloudHoursPurchasePhase.credited,
          selectedProductId: request.productId,
          isRestore: restored,
        );
        return;
      }

      state = CloudHoursPurchaseState(
        phase: result.status == StorePurchaseStatus.pending
            ? CloudHoursPurchasePhase.pending
            : CloudHoursPurchasePhase.failed,
        selectedProductId: request.productId,
        errorMessage: result.status == StorePurchaseStatus.rejected
            ? 'Store receipt was rejected.'
            : null,
        isRestore: restored,
      );
    } on Object catch (error) {
      state = CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.failed,
        selectedProductId: request.productId,
        errorMessage: error.toString(),
        isRestore: restored,
      );
    }
  }

  void _refreshPurchasedData() {
    ref.invalidate(entitlementProvider);
    ref.invalidate(watchListProvider);
    ref.invalidate(homeDashboardProvider);
    ref.read(watchRevisionProvider.notifier).bump();
  }
}

CloudHoursPurchaseContext cloudHoursPurchaseContextFromValue(String? value) {
  return CloudHoursPurchaseContext.values.firstWhere(
    (CloudHoursPurchaseContext item) => item.name == value,
    orElse: () => CloudHoursPurchaseContext.autoRecord,
  );
}
