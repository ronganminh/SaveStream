class CreditBalance {
  const CreditBalance({
    required this.posted,
    required this.reserved,
    required this.available,
  });

  final double posted;
  final double reserved;
  final double available;
}

class CreditUsageSummary {
  const CreditUsageSummary({
    required this.recordingHours,
    required this.recordingCount,
    required this.recordingCost,
  });

  final double recordingHours;
  final int recordingCount;
  final double recordingCost;
}

class CreditTransaction {
  const CreditTransaction({
    required this.id,
    required this.amountCredits,
    required this.occurredAt,
    this.recordingId,
  });

  final String id;
  final double amountCredits;
  final DateTime occurredAt;
  final String? recordingId;

  bool get isCredit => amountCredits >= 0;
}

class CreditsOverview {
  const CreditsOverview({
    required this.balance,
    required this.usage,
    required this.transactions,
  });

  final CreditBalance balance;
  final CreditUsageSummary usage;
  final List<CreditTransaction> transactions;

  static const double lowCreditThreshold = 5;

  bool get isLowCredit =>
      balance.available > 0 && balance.available <= lowCreditThreshold;
}
