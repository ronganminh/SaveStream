enum CreditTransactionType {
  grant('grant'),
  charge('charge'),
  release('release'),
  adjustment('adjustment'),
  refund('refund');

  const CreditTransactionType(this.apiValue);

  final String apiValue;
}

enum CreditReservationStatus {
  active('active'),
  settled('settled'),
  released('released');

  const CreditReservationStatus(this.apiValue);

  final String apiValue;
}

class CreditBalance {
  const CreditBalance({
    required this.posted,
    required this.reserved,
    required this.available,
  });

  final int posted;
  final int reserved;
  final int available;
}

class CreditTransaction {
  const CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.referenceType,
    required this.occurredAt,
    this.referenceId,
  });

  final String id;
  final CreditTransactionType type;
  final int amount;
  final int balanceAfter;
  final String referenceType;
  final String? referenceId;
  final DateTime occurredAt;

  bool get isCredit => amount >= 0;

  String? get recordingId => referenceType == 'recording' ? referenceId : null;
}

class CreditReservation {
  const CreditReservation({
    required this.id,
    required this.recordingId,
    required this.reserved,
    required this.settled,
    required this.released,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String recordingId;
  final int reserved;
  final int settled;
  final int released;
  final CreditReservationStatus status;
  final DateTime createdAt;
}

class PricingSnapshot {
  const PricingSnapshot({
    required this.version,
    required this.creditUnit,
    required this.rules,
  });

  final String version;
  final String creditUnit;
  final List<Map<String, Object?>> rules;
}

class CreditsOverview {
  const CreditsOverview({
    required this.balance,
    required this.transactions,
    required this.reservations,
    this.pricing,
  });

  final CreditBalance balance;
  final List<CreditTransaction> transactions;
  final List<CreditReservation> reservations;
  final PricingSnapshot? pricing;

  static const int lowCreditThreshold = 5;

  bool get isLowCredit =>
      balance.available > 0 && balance.available <= lowCreditThreshold;

  int get activeReservationCount =>
      reservations.where((CreditReservation item) {
        return item.status == CreditReservationStatus.active;
      }).length;
}
