import '../../domain/models/credit_models.dart';

final class CreditApiPage<T> {
  const CreditApiPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

CreditBalance creditBalanceFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'credit balance');
  return CreditBalance(
    posted: _requiredInt(map['posted'], 'posted'),
    reserved: _requiredInt(map['reserved'], 'reserved'),
    available: _requiredInt(map['available'], 'available'),
  );
}

CreditApiPage<CreditTransaction> creditTransactionsFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'credit transactions');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Credit transactions must be an array.');
  }
  final _Pagination pagination = _pagination(map['pagination']);
  return CreditApiPage<CreditTransaction>(
    items: rawItems.map<CreditTransaction>((Object? raw) {
      final Map<Object?, Object?> item = _requiredMap(
        raw,
        'credit transaction',
      );
      return CreditTransaction(
        id: _requiredString(item['id'], 'transaction.id'),
        type: _transactionType(
          _requiredString(item['type'], 'transaction.type'),
        ),
        amount: _requiredSignedInt(item['amount'], 'transaction.amount'),
        balanceAfter: _requiredSignedInt(
          item['balance_after'],
          'transaction.balance_after',
        ),
        referenceType: _requiredString(
          item['reference_type'],
          'transaction.reference_type',
        ),
        referenceId: _optionalString(
          item['reference_id'],
          'transaction.reference_id',
        ),
        occurredAt: _requiredDateTime(
          item['created_at'],
          'transaction.created_at',
        ),
      );
    }).toList(growable: false),
    nextCursor: pagination.nextCursor,
    hasMore: pagination.hasMore,
  );
}

CreditApiPage<CreditReservation> creditReservationsFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'credit reservations');
  final Object? rawItems = map['items'];
  if (rawItems is! List) {
    throw const FormatException('Credit reservations must be an array.');
  }
  final _Pagination pagination = _pagination(map['pagination']);
  return CreditApiPage<CreditReservation>(
    items: rawItems.map<CreditReservation>((Object? raw) {
      final Map<Object?, Object?> item = _requiredMap(
        raw,
        'credit reservation',
      );
      return CreditReservation(
        id: _requiredString(item['id'], 'reservation.id'),
        recordingId: _requiredString(
          item['recording_id'],
          'reservation.recording_id',
        ),
        reserved: _requiredInt(item['reserved'], 'reservation.reserved'),
        settled: _requiredInt(item['settled'], 'reservation.settled'),
        released: _requiredInt(item['released'], 'reservation.released'),
        status: _reservationStatus(
          _requiredString(item['status'], 'reservation.status'),
        ),
        createdAt: _requiredDateTime(
          item['created_at'],
          'reservation.created_at',
        ),
      );
    }).toList(growable: false),
    nextCursor: pagination.nextCursor,
    hasMore: pagination.hasMore,
  );
}

PricingSnapshot pricingFromJson(Object? json) {
  final Map<Object?, Object?> map = _requiredMap(json, 'pricing');
  if (map['credit_unit'] != 'credit') {
    throw const FormatException('Unsupported pricing credit unit.');
  }
  final Object? rawRules = map['rules'];
  if (rawRules is! List) {
    throw const FormatException('Pricing rules must be an array.');
  }
  return PricingSnapshot(
    version: _requiredString(map['version'], 'pricing.version'),
    creditUnit: 'credit',
    rules: rawRules.map<Map<String, Object?>>((Object? raw) {
      final Map<Object?, Object?> source = _requiredMap(raw, 'pricing rule');
      return Map<String, Object?>.unmodifiable(
        source.map<String, Object?>(
          (Object? key, Object? value) => MapEntry<String, Object?>(
            key.toString(),
            value,
          ),
        ),
      );
    }).toList(growable: false),
  );
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
      'Paginated credit response must include next_cursor.',
    );
  }
  return _Pagination(hasMore: hasMore, nextCursor: nextCursor);
}

CreditTransactionType _transactionType(String value) {
  return switch (value) {
    'grant' => CreditTransactionType.grant,
    'charge' => CreditTransactionType.charge,
    'release' => CreditTransactionType.release,
    'adjustment' => CreditTransactionType.adjustment,
    'refund' => CreditTransactionType.refund,
    _ => throw FormatException('Unsupported credit transaction type: $value'),
  };
}

CreditReservationStatus _reservationStatus(String value) {
  return switch (value) {
    'active' => CreditReservationStatus.active,
    'settled' => CreditReservationStatus.settled,
    'released' => CreditReservationStatus.released,
    _ => throw FormatException('Unsupported credit reservation status: $value'),
  };
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

int _requiredSignedInt(Object? value, String name) {
  if (value is! int) {
    throw FormatException('Expected $name integer.');
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
