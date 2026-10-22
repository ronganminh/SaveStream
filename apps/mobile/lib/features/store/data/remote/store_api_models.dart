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
  // Web-only packages have no store ids (null); stores skip them.
  final Object? rawIds = map['store_product_ids'];
  final Map<Object?, Object?> productIds = rawIds is Map
      ? rawIds
      : const <Object?, Object?>{};
  return StorePackage(
    id: _requiredString(map['id'], 'package.id'),
    name: _requiredString(map['name'], 'package.name'),
    cloudMinutes: _requiredInt(map['cloud_minutes'], 'package.cloud_minutes'),
    // Each store id stands alone (Android sells without an Apple id); a
    // missing one is empty and that store does not offer the package.
    productIds: StoreProductIds(
      appStore: _optionalString(productIds['app_store']),
      googlePlay: _optionalString(productIds['google_play']),
    ),
  );
}

StorePurchaseResult storePurchaseResultFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'store purchase');
  return StorePurchaseResult(
    status: switch (_requiredString(map['status'], 'purchase.status')) {
      'credited' => StorePurchaseStatus.credited,
      // `payment_pending`: Google Play is still confirming the payment
      // (e.g. cash); the server grants it when Play reports it paid.
      'pending' || 'payment_pending' => StorePurchaseStatus.pending,
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

String _optionalString(Object? value) => value is String ? value.trim() : '';

int _requiredInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('Expected non-negative $name integer.');
  }
  return value;
}
