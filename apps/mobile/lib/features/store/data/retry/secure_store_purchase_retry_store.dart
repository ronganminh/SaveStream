import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/store_models.dart';
import '../../domain/repositories/store_purchase_retry_store.dart';

final class SecureStorePurchaseRetryStore implements StorePurchaseRetryStore {
  SecureStorePurchaseRetryStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'savestream.pending_store_purchases.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<List<StorePurchaseRequest>> load() async {
    final String? raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return const <StorePurchaseRequest>[];
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const <StorePurchaseRequest>[];
    }
    return decoded
        .whereType<Map>()
        .map<StorePurchaseRequest>(_fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> put(StorePurchaseRequest request) async {
    final Map<String, StorePurchaseRequest> items =
        <String, StorePurchaseRequest>{
          for (final StorePurchaseRequest item in await load())
            item.transactionId: item,
          request.transactionId: request,
        };
    await _write(items.values);
  }

  @override
  Future<void> remove(String transactionId) async {
    final List<StorePurchaseRequest> items = await load();
    await _write(
      items.where(
        (StorePurchaseRequest item) => item.transactionId != transactionId,
      ),
    );
  }

  Future<void> _write(Iterable<StorePurchaseRequest> items) {
    final List<Map<String, Object?>> encoded = items
        .map<Map<String, Object?>>(_toJson)
        .toList(growable: false);
    if (encoded.isEmpty) {
      return _storage.delete(key: _key);
    }
    return _storage.write(key: _key, value: jsonEncode(encoded));
  }

  Map<String, Object?> _toJson(StorePurchaseRequest request) {
    return <String, Object?>{
      'platform': request.platform.name,
      'product_id': request.productId,
      'transaction_id': request.transactionId,
      'receipt': request.receipt,
    };
  }

  StorePurchaseRequest _fromJson(Map<Object?, Object?> json) {
    final Object? platform = json['platform'];
    final Object? productId = json['product_id'];
    final Object? transactionId = json['transaction_id'];
    final Object? receipt = json['receipt'];
    if (platform is! String ||
        productId is! String ||
        transactionId is! String ||
        receipt is! String) {
      throw const FormatException('Invalid pending store purchase.');
    }
    return StorePurchaseRequest(
      platform: switch (platform) {
        'appStore' => StorePurchasePlatform.appStore,
        'googlePlay' => StorePurchasePlatform.googlePlay,
        _ => throw FormatException('Unsupported store platform: $platform'),
      },
      productId: productId,
      transactionId: transactionId,
      receipt: receipt,
    );
  }
}
