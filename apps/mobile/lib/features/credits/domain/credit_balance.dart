/// `GET /v1/credits/balance`. One credit is one cloud recording minute.
class CreditBalance {
  const CreditBalance({
    required this.posted,
    required this.reserved,
    required this.available,
    this.refundDebt = 0,
  });

  final int posted;
  final int reserved;
  final int available;

  /// Minutes owed after a store refund of credit that was already spent.
  /// Recording stays blocked until a purchase pays it off.
  final int refundDebt;

  bool get hasRefundDebt => refundDebt > 0;
}

abstract interface class CreditsRepository {
  Future<CreditBalance> getBalance();
}
