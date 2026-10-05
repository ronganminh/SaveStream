import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/mock/mock_providers.dart';
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
  });

  final StorePackage package;
  final String productId;
  final String localizedPrice;

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

final FutureProvider<List<CloudHoursOffer>> cloudHoursOffersProvider =
    FutureProvider<List<CloudHoursOffer>>((Ref ref) async {
      final List<StorePackage> packages = await ref
          .watch(storeRepositoryProvider)
          .listPackages();
      final DevicePlatform platform = ref
          .watch(deviceInfoServiceProvider)
          .platform;
      final List<String> ids = packages
          .map(
            (StorePackage package) => platform == DevicePlatform.ios
                ? package.productIds.appStore
                : package.productIds.googlePlay,
          )
          .toList(growable: false);

      final products = await ref
          .watch(purchaseServiceProvider)
          .loadProducts(ids);
      final Map<String, String> prices = <String, String>{
        for (final product in products) product.id: product.localizedPrice,
      };

      return <CloudHoursOffer>[
        for (int index = 0; index < packages.length; index += 1)
          CloudHoursOffer(
            package: packages[index],
            productId: ids[index],
            localizedPrice: prices[ids[index]] ?? '',
          ),
      ];
    });
