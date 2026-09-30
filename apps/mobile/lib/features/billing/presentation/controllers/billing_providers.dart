import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_providers.dart';
import '../../data/repositories/mock_billing_repository.dart';
import '../../domain/models/billing_models.dart';
import '../../domain/repositories/billing_repository.dart';

final Provider<BillingRepository> billingRepositoryProvider =
    Provider<BillingRepository>(
      (ref) => MockBillingRepository(ref.watch(mockBehaviorProvider)),
    );

final NotifierProvider<BillingRevisionNotifier, int> billingRevisionProvider =
    NotifierProvider<BillingRevisionNotifier, int>(BillingRevisionNotifier.new);

class BillingRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

final FutureProvider<BillingSnapshot> billingSnapshotProvider =
    FutureProvider<BillingSnapshot>((ref) {
      ref.watch(billingRevisionProvider);
      return ref.watch(billingRepositoryProvider).getSnapshot();
    });

final Provider<BillingController> billingControllerProvider =
    Provider<BillingController>((ref) {
      return BillingController(
        repository: ref.watch(billingRepositoryProvider),
        onChanged: () => ref.read(billingRevisionProvider.notifier).bump(),
      );
    });

class BillingController {
  const BillingController({
    required BillingRepository repository,
    required void Function() onChanged,
  }) : _repository = repository,
       _onChanged = onChanged;

  final BillingRepository _repository;
  final void Function() _onChanged;

  Future<PaymentOrder?> createOrder(String packageId) async {
    final PaymentOrder? order = await _repository.createPaymentOrder(packageId);
    _onChanged();
    return order;
  }

  Future<PaymentOrder?> refreshOrder(String orderId) async {
    final PaymentOrder? order = await _repository.refreshPaymentOrder(orderId);
    _onChanged();
    return order;
  }
}
