/// `GET /v1/credits/transactions`: the credit ledger, newest first. One
/// credit is one cloud recording minute.
enum CreditTransactionType { grant, charge, release, adjustment, refund }

class CreditTransaction {
  const CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.referenceType,
    required this.createdAt,
    this.referenceId,
    this.releasedCredits,
    this.storeOrderId,
    this.packageName,
    this.recordingChannelUsername,
    this.recordingDurationSeconds,
  });

  final String id;
  final CreditTransactionType type;

  /// Signed minutes (negative for a charge).
  final int amount;
  final int balanceAfter;

  /// What the entry is for: `payment_order`, `reward`, `recording`,
  /// `signup_bonus`, `promotion`, `refund`, `store_refund`, …
  final String referenceType;
  final String? referenceId;

  /// For a `release`: minutes returned from a recording hold.
  final int? releasedCredits;

  /// Payment-order entries: Google Play's order id (`GPA.…`) and pack name.
  final String? storeOrderId;
  final String? packageName;

  /// Recording entries: the channel and how long it recorded.
  final String? recordingChannelUsername;
  final int? recordingDurationSeconds;
  final DateTime createdAt;
}

class CreditTransactionPage {
  const CreditTransactionPage({required this.items, this.nextCursor});

  final List<CreditTransaction> items;
  final String? nextCursor;
}

/// `GET /v1/billing/payment-orders`: purchases of minute packs.
enum PaymentOrderStatus {
  created,
  pending,
  paid,
  failed,
  cancelled,
  expired,
  partiallyRefunded,
  refunded,
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.packageId,
    required this.status,
    required this.credits,
    required this.createdAt,
    this.provider,
    this.storeOrderId,
    this.clientPriceAmountMicros,
    this.clientPriceCurrency,
  });

  final String id;
  final String packageId;
  final PaymentOrderStatus status;
  final int credits;

  /// `google_play`, `app_store`, `paypal`, …
  final String? provider;

  /// Google Play's order id (`GPA.…`); null for promo codes and web orders.
  final String? storeOrderId;

  /// The store price the app reported when it bought (display only).
  final int? clientPriceAmountMicros;
  final String? clientPriceCurrency;
  final DateTime createdAt;
}

/// `POST /v1/rewards` (purpose `cloud_minutes`): one rewarded-ad intent.
/// The ad is shown with [ssvUserId] / [ssvCustomData] as server-side
/// verification options; AdMob's callback then credits the minutes.
class RewardIntent {
  const RewardIntent({
    required this.rewardId,
    required this.ssvUserId,
    required this.ssvCustomData,
    required this.expiresAt,
  });

  final String rewardId;
  final String ssvUserId;
  final String ssvCustomData;
  final DateTime expiresAt;
}

enum RewardStatus { pending, valid, invalid, expired }

abstract interface class CreditLedgerRepository {
  Future<CreditTransactionPage> listTransactions({
    String? cursor,
    int limit = 50,
  });

  Future<List<PaymentOrder>> listPaymentOrders();
}

abstract interface class RewardsRepository {
  Future<RewardIntent> createCloudMinutesReward({required String deviceId});

  Future<RewardStatus> getRewardStatus(String rewardId);
}
