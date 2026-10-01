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
    final StringBuffer buffer = StringBuffer('idem_');
    for (int index = 0; index < 16; index += 1) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
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
