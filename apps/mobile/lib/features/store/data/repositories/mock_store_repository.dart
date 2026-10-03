import '../../../../core/mock/mock_repository_base.dart';
import '../../domain/models/store_models.dart';
import '../../domain/repositories/store_repository.dart';

final class MockStoreRepository extends MockRepositoryBase
    implements StoreRepository {
  const MockStoreRepository(super.behavior);

  static const List<StorePackage> packages = <StorePackage>[
    StorePackage(
      id: 'starter',
      name: 'Starter',
      cloudMinutes: 3000,
      productIds: StoreProductIds(
        appStore: 'savestream.hours.50',
        googlePlay: 'savestream.hours.50',
      ),
    ),
    StorePackage(
      id: 'standard',
      name: 'Standard',
      cloudMinutes: 9000,
      productIds: StoreProductIds(
        appStore: 'savestream.hours.150',
        googlePlay: 'savestream.hours.150',
      ),
    ),
    StorePackage(
      id: 'premium',
      name: 'Premium',
      cloudMinutes: 24000,
      productIds: StoreProductIds(
        appStore: 'savestream.hours.400',
        googlePlay: 'savestream.hours.400',
      ),
    ),
  ];

  @override
  Future<List<StorePackage>> listPackages() {
    return respond<List<StorePackage>>(
      success: () => packages,
      empty: () => const <StorePackage>[],
    );
  }

  @override
  Future<StorePurchaseResult> submitPurchase(StorePurchaseRequest request) {
    return respond<StorePurchaseResult>(
      success: () {
        final StorePackage package = packages.firstWhere(
          (StorePackage item) =>
              item.productIds.appStore == request.productId ||
              item.productIds.googlePlay == request.productId,
        );
        return StorePurchaseResult(
          status: StorePurchaseStatus.credited,
          paymentOrderId: 'ord_mock',
          cloudMinutesAdded: package.cloudMinutes,
          cloudMinutesAvailable: package.cloudMinutes,
        );
      },
      empty: () => const StorePurchaseResult(
        status: StorePurchaseStatus.pending,
        paymentOrderId: 'ord_pending',
        cloudMinutesAdded: 0,
        cloudMinutesAvailable: 0,
      ),
    );
  }
}
