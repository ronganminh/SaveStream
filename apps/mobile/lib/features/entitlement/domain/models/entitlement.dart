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

class Entitlement {
  const Entitlement({
    required this.plan,
    required this.hasPurchased,
    required this.cloudMinutesAvailable,
    required this.limits,
    required this.watchCount,
    required this.local,
    required this.updatedAt,
  });

  final Plan plan;
  final bool hasPurchased;
  final int cloudMinutesAvailable;
  final EntitlementLimits limits;
  final int watchCount;
  final LocalEntitlement local;
  final DateTime updatedAt;
}
