import '../models/store_models.dart';

abstract interface class StorePurchaseRetryStore {
  Future<List<StorePurchaseRequest>> load();

  Future<void> put(StorePurchaseRequest request);

  Future<void> remove(String transactionId);
}
