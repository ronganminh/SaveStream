import '../../../credits/domain/credit_balance.dart';
import '../../../entitlement/domain/models/entitlement.dart';

enum HomeCreditsTone { normal, low, out }

enum HomeCreditsCaption {
  /// Free trial, nothing used yet.
  trial,

  /// Free trial, some minutes used ("Free trial · 8 of 10 minutes used").
  trialUsed,

  /// Trial locked until the email is verified.
  unverified,

  /// Purchased minutes.
  purchased,

  /// No minutes (or a refund debt): recording is paused.
  paused,
}

/// What the Home credits card shows, derived from `/v1/me/entitlement` and
/// `/v1/credits/balance`.
class HomeCredits {
  const HomeCredits({
    required this.minutes,
    required this.tone,
    required this.caption,
    required this.isTrial,
    this.progress,
    this.refundDebt = 0,
  });

  /// Free trial size granted on a verified email.
  static const int trialMinutes = 10;

  /// At or below this many minutes the card turns amber.
  static const int lowTrialThreshold = 3;
  static const int lowPurchasedThreshold = 15;

  final int minutes;
  final HomeCreditsTone tone;
  final HomeCreditsCaption caption;
  final bool isTrial;

  /// Bar fill (0–1). Null when there is no meaningful total to compare to.
  final double? progress;
  final int refundDebt;

  int get trialMinutesUsed =>
      (trialMinutes - minutes).clamp(0, trialMinutes).toInt();

  factory HomeCredits.from(Entitlement entitlement, CreditBalance? balance) {
    final int minutes = entitlement.cloudMinutesAvailable;
    final int refundDebt = balance?.refundDebt ?? 0;
    final bool isTrial = !entitlement.hasPurchased;
    final HomeCreditsTone tone;
    if (minutes <= 0 || refundDebt > 0) {
      tone = HomeCreditsTone.out;
    } else if (minutes <=
        (isTrial ? lowTrialThreshold : lowPurchasedThreshold)) {
      tone = HomeCreditsTone.low;
    } else {
      tone = HomeCreditsTone.normal;
    }

    final HomeCreditsCaption caption;
    if (tone == HomeCreditsTone.out) {
      caption = isTrial && !entitlement.emailVerified
          ? HomeCreditsCaption.unverified
          : HomeCreditsCaption.paused;
    } else if (!isTrial) {
      caption = HomeCreditsCaption.purchased;
    } else if (minutes >= trialMinutes) {
      caption = HomeCreditsCaption.trial;
    } else {
      caption = HomeCreditsCaption.trialUsed;
    }

    // The bar compares the balance with the server's cycle total (balance
    // after the latest top-up plus minutes granted since). Older servers
    // send none: then only the free trial has a known size.
    final int? cycleTotal = entitlement.cloudMinutesCycleTotal;
    final double? progress = tone == HomeCreditsTone.out
        ? 0
        : cycleTotal != null && cycleTotal > 0
        ? (minutes / cycleTotal).clamp(0, 1).toDouble()
        : isTrial
        ? (minutes / trialMinutes).clamp(0, 1).toDouble()
        : null;

    return HomeCredits(
      minutes: refundDebt > 0 ? 0 : minutes,
      tone: tone,
      caption: caption,
      isTrial: isTrial,
      progress: progress,
      refundDebt: refundDebt,
    );
  }
}
