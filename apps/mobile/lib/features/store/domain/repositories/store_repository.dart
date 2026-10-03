import '../models/store_models.dart';

abstract interface class StoreRepository {
  Future<List<StorePackage>> listPackages();

  Future<StorePurchaseResult> submitPurchase(StorePurchaseRequest request);
}
