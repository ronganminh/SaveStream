import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../platform/contracts/purchase_service.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
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
  });

  final CloudHoursPurchasePhase phase;
  final String? selectedProductId;
  final String? errorMessage;
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
    _subscription = ref.watch(purchaseServiceProvider).purchaseEvents.listen(
      _handlePurchaseEvent,
    );
    ref.onDispose(() => _subscription?.cancel());
    return const CloudHoursPurchaseState();
  }

  Future<void> buy(CloudHoursOffer offer) async {
    state = CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.processing,
      selectedProductId: offer.productId,
    );
    await ref.read(purchaseServiceProvider).buy(offer.productId);
  }

  Future<void> restore() async {
    state = const CloudHoursPurchaseState(
      phase: CloudHoursPurchasePhase.restoring,
    );
    await ref.read(purchaseServiceProvider).restore();
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
        selectedProductId: event.productId,
        errorMessage: event.errorMessage,
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
    if (event.status == PurchaseEventStatus.restored) {
      state = const CloudHoursPurchaseState(
        phase: CloudHoursPurchasePhase.restored,
      );
      return;
    }
    if (event.status != PurchaseEventStatus.purchased ||
        event.transactionId == null ||
        event.receipt == null) {
      return;
    }

    final DevicePlatform platform = ref.read(deviceInfoServiceProvider).platform;
    final StorePurchaseResult result = await ref
        .read(storeRepositoryProvider)
        .submitPurchase(
          StorePurchaseRequest(
            platform: platform == DevicePlatform.ios
                ? StorePurchasePlatform.appStore
                : StorePurchasePlatform.googlePlay,
            productId: event.productId,
            transactionId: event.transactionId!,
            receipt: event.receipt!,
          ),
        );

    state = CloudHoursPurchaseState(
      phase: result.status == StorePurchaseStatus.credited
          ? CloudHoursPurchasePhase.credited
          : CloudHoursPurchasePhase.pending,
      selectedProductId: event.productId,
    );
  }
}
