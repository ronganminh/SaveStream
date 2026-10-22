import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_providers.dart';
import '../../../platform/contracts/purchase_service.dart';
import '../../../platform/platform_providers.dart';
import '../../devices/domain/models/device_registration.dart';
import '../data/repositories/mock_store_repository.dart';
import '../data/retry/memory_store_purchase_retry_store.dart';
import '../domain/models/store_models.dart';
import '../domain/repositories/store_purchase_retry_store.dart';
import '../domain/repositories/store_repository.dart';

class CloudHoursOffer {
  const CloudHoursOffer({
    required this.package,
    required this.productId,
    required this.localizedPrice,
    this.priceAmountMicros,
    this.currencyCode,
  });

  final StorePackage package;
  final String productId;
  final String localizedPrice;
  final int? priceAmountMicros;
  final String? currencyCode;

  int get hours => package.cloudMinutes ~/ 60;
}

final Provider<StoreRepository> storeRepositoryProvider =
    Provider<StoreRepository>(
      (Ref ref) => MockStoreRepository(ref.watch(mockBehaviorProvider)),
    );

final Provider<StorePurchaseRetryStore> storePurchaseRetryStoreProvider =
    Provider<StorePurchaseRetryStore>(
      (Ref ref) => MemoryStorePurchaseRetryStore(),
    );

/// `GET /v1/billing/packages`: names and minutes of the packs.
final FutureProvider<List<StorePackage>> storePackagesProvider =
    FutureProvider<List<StorePackage>>(
      (Ref ref) => ref.watch(storeRepositoryProvider).listPackages(),
    );

final FutureProvider<List<CloudHoursOffer>> cloudHoursOffersProvider =
    FutureProvider<List<CloudHoursOffer>>((Ref ref) async {
      final List<StorePackage> packages = await ref.watch(
        storePackagesProvider.future,
      );
      final DevicePlatform platform = ref
          .watch(deviceInfoServiceProvider)
          .platform;
      String productIdOf(StorePackage package) => platform == DevicePlatform.ios
          ? package.productIds.appStore
          : package.productIds.googlePlay;
      final List<StorePackage> sellable = packages
          .where((StorePackage package) => productIdOf(package).isNotEmpty)
          .toList(growable: false);

      final products = await ref
          .watch(purchaseServiceProvider)
          .loadProducts(sellable.map(productIdOf));
      final Map<String, StoreProductInfo> details = <String, StoreProductInfo>{
        for (final StoreProductInfo product in products) product.id: product,
      };
      final Map<String, String> prices = <String, String>{
        for (final StoreProductInfo product in products)
          product.id: product.localizedPrice,
      };

      // Prices only ever come from the store: a pack the store doesn't
      // return (not active in Play Console) is not offered.
      return <CloudHoursOffer>[
        for (final StorePackage package in sellable)
          if ((prices[productIdOf(package)] ?? '').isNotEmpty)
            CloudHoursOffer(
              package: package,
              productId: productIdOf(package),
              localizedPrice: prices[productIdOf(package)]!,
              priceAmountMicros:
                  details[productIdOf(package)]?.priceAmountMicros,
              currencyCode: details[productIdOf(package)]?.currencyCode,
            ),
      ];
    });
