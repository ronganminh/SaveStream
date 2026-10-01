import '../../domain/models/billing_models.dart';

final class BillingApiPage<T> {
  const BillingApiPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

List<CreditPackage> creditPackagesFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'credit packages');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Credit packages must be an array.');
  }
  return rawItems
      .map<CreditPackage>(creditPackageFromJson)
      .toList(growable: false);
}

CreditPackage creditPackageFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'credit package');
  return CreditPackage(
    id: _requiredString(map['id'], 'package.id'),
    name: _requiredString(map['name'], 'package.name'),
    credits: _requiredInt(map['credits'], 'package.credits'),
    price: _money(map['price'], 'package.price'),
    active: _requiredBool(map['active'], 'package.active'),
  );
}

BillingApiPage<PaymentOrder> paymentOrdersFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'payment orders');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Payment orders must be an array.');
  }
  final _Pagination pagination = _pagination(map['pagination']);
  return BillingApiPage<PaymentOrder>(
    items: rawItems
        .map<PaymentOrder>(paymentOrderFromJson)
        .toList(growable: false),
    nextCursor: pagination.nextCursor,
    hasMore: pagination.hasMore,
  );
}

PaymentOrder paymentOrderFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'payment order');
  return PaymentOrder(
    id: _requiredString(map['id'], 'payment_order.id'),
    packageId: _requiredString(map['package_id'], 'payment_order.package_id'),
    status: _paymentStatus(
      _requiredString(map['status'], 'payment_order.status'),
    ),
    credits: _requiredInt(map['credits'], 'payment_order.credits'),
    amount: _money(map['amount'], 'payment_order.amount'),
    provider: _optionalString(map['provider'], 'payment_order.provider'),
    providerReference: _optionalString(
      map['provider_reference'],
      'payment_order.provider_reference',
    ),
    createdAt: _requiredDateTime(map['created_at'], 'payment_order.created_at'),
    updatedAt: _requiredDateTime(map['updated_at'], 'payment_order.updated_at'),
  );
}

CheckoutSession checkoutSessionFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'checkout');
  final String rawUrl = _requiredString(map['checkout_url'], 'checkout_url');
  final Uri? uri = Uri.tryParse(rawUrl);
  if (uri == null || !uri.hasScheme) {
    throw const FormatException('Checkout URL must be absolute.');
  }
  return CheckoutSession(
    checkoutUri: uri,
    paymentOrder: paymentOrderFromJson(map['payment_order']),
  );
}

Money _money(Object? json, String name) {
  final Map<Object?, Object?> map = _requiredMap(json, name);
  final String currency = _requiredString(
    map['currency'],
    '$name.currency',
  ).toUpperCase();
  if (currency.length != 3) {
    throw FormatException('$name.currency must be ISO-4217 length.');
  }
  return Money(
    amountMinor: _requiredInt(map['amount_minor'], '$name.amount_minor'),
    currency: currency,
  );
}

PaymentOrderStatus _paymentStatus(String value) {
  return switch (value) {
    'created' => PaymentOrderStatus.created,
    'pending' => PaymentOrderStatus.pending,
    'paid' => PaymentOrderStatus.paid,
    'failed' => PaymentOrderStatus.failed,
    'cancelled' => PaymentOrderStatus.cancelled,
    'expired' => PaymentOrderStatus.expired,
    'partially_refunded' => PaymentOrderStatus.partiallyRefunded,
    'refunded' => PaymentOrderStatus.refunded,
    _ => throw FormatException('Unsupported payment status: $value'),
  };
}

final class _Pagination {
  const _Pagination({required this.hasMore, this.nextCursor});

  final bool hasMore;
  final String? nextCursor;
}

_Pagination _pagination(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'pagination');
  final bool hasMore = _requiredBool(map['has_more'], 'pagination.has_more');
  final String? nextCursor = _optionalString(
    map['next_cursor'],
    'pagination.next_cursor',
  );
  if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
    throw const FormatException(
      'Paginated billing response must include next_cursor.',
    );
  }
  return _Pagination(hasMore: hasMore, nextCursor: nextCursor);
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

String? _optionalString(Object? value, String name) {
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('Expected nullable $name string.');
  }
  return value.trim();
}

int _requiredInt(Object? value, String name) {
  if (value is! int || value < 0) {
    throw FormatException('Expected non-negative $name integer.');
  }
  return value;
}

bool _requiredBool(Object? value, String name) {
  if (value is! bool) {
    throw FormatException('Expected $name boolean.');
  }
  return value;
}

DateTime _requiredDateTime(Object? value, String name) {
  if (value is! String) {
    throw FormatException('Expected $name timestamp.');
  }
  final DateTime? parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) {
    throw FormatException('Expected valid $name timestamp.');
  }
  return parsed;
}
