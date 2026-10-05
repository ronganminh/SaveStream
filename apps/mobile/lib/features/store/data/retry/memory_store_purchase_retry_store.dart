import '../../domain/models/store_models.dart';
import '../../domain/repositories/store_purchase_retry_store.dart';

final class MemoryStorePurchaseRetryStore implements StorePurchaseRetryStore {
  final Map<String, StorePurchaseRequest> _items =
      <String, StorePurchaseRequest>{};

  @override
  Future<List<StorePurchaseRequest>> load() async =>
      List<StorePurchaseRequest>.unmodifiable(_items.values);

  @override
  Future<void> put(StorePurchaseRequest request) async {
    _items[request.transactionId] = request;
  }

  @override
  Future<void> remove(String transactionId) async {
    _items.remove(transactionId);
  }
}
