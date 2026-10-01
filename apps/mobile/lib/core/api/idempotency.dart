import 'dart:math';

abstract interface class IdempotencyKeyGenerator {
  String nextKey();
}

final class SecureIdempotencyKeyGenerator implements IdempotencyKeyGenerator {
  SecureIdempotencyKeyGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  String nextKey() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex = bytes
        .map((int value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

final class IdempotencyContext {
  IdempotencyContext._(this.key);

  factory IdempotencyContext.create(IdempotencyKeyGenerator generator) {
    return IdempotencyContext._(generator.nextKey());
  }

  factory IdempotencyContext.fromKey(String key) {
    final String normalized = key.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(key, 'key', 'Idempotency key cannot be empty.');
    }
    return IdempotencyContext._(normalized);
  }

  final String key;
}
