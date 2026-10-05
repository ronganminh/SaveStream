import '../../../../core/api/api_client.dart';
import '../../domain/models/store_models.dart';
import '../../domain/repositories/store_repository.dart';
import '../remote/store_api_models.dart';

final class ApiStoreRepository implements StoreRepository {
  const ApiStoreRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<StorePackage>> listPackages() async {
    final response = await _apiClient.get<List<StorePackage>>(
      '/v1/billing/packages',
      decoder: storePackagesFromJson,
    );
    return List<StorePackage>.unmodifiable(response.data);
  }

  @override
  Future<StorePurchaseResult> submitPurchase(
    StorePurchaseRequest request,
  ) async {
    final response = await _apiClient.post<StorePurchaseResult>(
      '/v1/billing/store-purchases',
      data: <String, Object?>{
        'platform': switch (request.platform) {
          StorePurchasePlatform.appStore => 'app_store',
          StorePurchasePlatform.googlePlay => 'google_play',
        },
        'product_id': request.productId,
        'transaction_id': request.transactionId,
        'receipt': request.receipt,
      },
      decoder: storePurchaseResultFromJson,
    );
    return response.data;
  }
}
