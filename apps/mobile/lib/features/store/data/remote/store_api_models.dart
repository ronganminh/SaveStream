import '../../domain/models/store_models.dart';

List<StorePackage> storePackagesFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'store packages');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Store packages must be an array.');
  }
  return rawItems
      .map<StorePackage>(storePackageFromJson)
      .where((StorePackage item) => item.cloudMinutes > 0)
      .toList(growable: false);
}

StorePackage storePackageFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'store package');
  final Map<Object?, Object?> productIds = _requiredMap(
    map['store_product_ids'],
    'store_product_ids',
  );
  return StorePackage(
    id: _requiredString(map['id'], 'package.id'),
    name: _requiredString(map['name'], 'package.name'),
    cloudMinutes: _requiredInt(map['cloud_minutes'], 'package.cloud_minutes'),
    productIds: StoreProductIds(
      appStore: _requiredString(productIds['app_store'], 'app_store'),
      googlePlay: _requiredString(productIds['google_play'], 'google_play'),
    ),
  );
}

StorePurchaseResult storePurchaseResultFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'store purchase');
  return StorePurchaseResult(
    status: switch (_requiredString(map['status'], 'purchase.status')) {
      'credited' => StorePurchaseStatus.credited,
      'pending' => StorePurchaseStatus.pending,
      'rejected' => StorePurchaseStatus.rejected,
      final String value => throw FormatException(
        'Unsupported store purchase status: $value',
      ),
    },
    paymentOrderId: _requiredString(
      map['payment_order_id'],
      'purchase.payment_order_id',
    ),
    cloudMinutesAdded: _requiredInt(
      map['cloud_minutes_added'],
      'purchase.cloud_minutes_added',
    ),
    cloudMinutesAvailable: _requiredInt(
      map['cloud_minutes_available'],
      'purchase.cloud_minutes_available',
    ),
  );
}

Map<Object?, Object?> _requiredMap(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('Expected $name object.');
  }
  return value;
}

String _requiredString(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected non-empty $name.');
  }
  return value.trim();
}

int _requiredInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('Expected non-negative $name integer.');
  }
  return value;
}
