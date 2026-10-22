enum Plan { free, pro }

enum Engine { local, cloud }

class EntitlementLimits {
  const EntitlementLimits({
    required this.maxWatches,
    required this.maxConcurrentCloudRecordings,
    required this.cloudRetentionDays,
  });

  final int maxWatches;
  final int maxConcurrentCloudRecordings;
  final int cloudRetentionDays;
}

class LocalEntitlement {
  const LocalEntitlement({
    required this.enabled,
    required this.unlimited,
    required this.dailyMinutes,
    required this.minutesRemaining,
    required this.resetsAt,
    required this.rewardsUsedToday,
    required this.rewardsCapPerDay,
    required this.minutesPerReward,
    required this.extensionsCapPerRecording,
    this.maxConcurrentSessions = 1,
    this.secondSlotExpiresAt,
  });

  final bool enabled;
  final bool unlimited;
  final int dailyMinutes;
  final int minutesRemaining;
  final DateTime resetsAt;
  final int rewardsUsedToday;
  final int rewardsCapPerDay;
  final int minutesPerReward;
  final int extensionsCapPerRecording;
  final int maxConcurrentSessions;
  final DateTime? secondSlotExpiresAt;
}

/// Entitlement `ads` block: the optional rewarded ad (+N cloud minutes,
/// verified by AdMob server-side verification) and whether the account
/// still sees the small banner (it never bought a pack).
class AdsEntitlement {
  const AdsEntitlement({
    required this.rewardedAvailable,
    required this.rewardsLeftToday,
    required this.rewardsCapPerDay,
    required this.minutesPerReward,
    required this.resetsAt,
    required this.showBanners,
  });

  final bool rewardedAvailable;
  final int rewardsLeftToday;
  final int rewardsCapPerDay;
  final int minutesPerReward;
  final DateTime resetsAt;
  final bool showBanners;

  int get rewardsUsedToday =>
      (rewardsCapPerDay - rewardsLeftToday).clamp(0, rewardsCapPerDay);
}

class Entitlement {
  const Entitlement({
    required this.plan,
    required this.hasPurchased,
    required this.cloudMinutesAvailable,
    required this.limits,
    required this.watchCount,
    required this.local,
    required this.updatedAt,
    this.emailVerified = false,
    this.canAutoRecord = false,
    this.trialRecording = false,
    this.ads,
    this.cloudMinutesCycleTotal,
    this.lastPackName,
    this.trialUsed = false,
  });

  final Plan plan;
  final bool hasPurchased;

  /// From `/v1/me/entitlement`: the free trial minutes unlock on a verified
  /// email, and auto-record needs purchased or trial credit.
  final bool emailVerified;
  final bool canAutoRecord;
  final bool trialRecording;
  final int cloudMinutesAvailable;
  final EntitlementLimits limits;
  final int watchCount;
  final LocalEntitlement local;
  final DateTime updatedAt;

  /// Null when the server predates the ads block (no ads then).
  final AdsEntitlement? ads;

  /// `cloud_minutes_cycle_total`: the N in "X minutes left of N" (balance
  /// right after the latest top-up plus minutes granted since). Null before
  /// any top-up or on an older server.
  final int? cloudMinutesCycleTotal;

  /// `last_pack_name`: the latest paid pack, null before the first purchase.
  final String? lastPackName;

  /// `trial_used`: the one-time free trial grant was ever made.
  final bool trialUsed;
}
