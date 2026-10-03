// Tên enum khớp với tag state trong annotation của từng màn (docs/SCREENS.md).
enum LiveStatus { live, offline, checking, unknown, paused }

enum RecordingStatus {
  starting,
  waitingForCloudSlot,
  recording,
  reconnecting,
  finalizing,
  processing,
  completed,
  partial,
  recovered,
  failed,
  missedNoCloudSlot,
  expired,
}

enum Engine { local, cloud }

enum Plan { free, pro }

enum EntitlementSource { none, appStore, googlePlay, web }

enum SubscriptionState { active, gracePeriod, billingRetry, expired, revoked } // revoked = PRO_REVOKED (M14), không grace

enum BillingPeriod { monthly, yearly }

enum PaywallContext { autoRecord, watchlistFull, iosBackground, quotaExhausted, removeAds }

enum PurchaseState { idle, storeSheet, verifying, success, cancelled, failed, pending }

enum RestoreState { checking, restored, nothingFound, error }

/// Baseline USD 1.99 / 5.99 / 12.99 — giá hiển thị LUÔN đọc từ storefront.
enum CloudPackSku { h5, h20, h60 }

enum CopyLocation { localOnly, cloudOnly, both } // L13

enum SessionState { valid, refreshing, expired } // G05

enum AppGate { ok, forceUpdate, maintenance } // G04 / G06

// Phase 8
enum CloudQuotaState { ok, low, exhausted } // CLOUD_QUOTA_EXHAUSTED

enum AutoRecordState { off, active, pausedNoCloudMinutes }

enum RecordingEndReason {
  userStopped,
  liveEnded,
  freeMinutesExhausted,
  storageLow,
  cloudPackDepleted, // CLOUD_PACK_DEPLETED_DURING_RECORDING (Q05)
  entitlementRevoked,
  error,
}

enum MissedReason { noCloudSlot, noCloudMinutes }

enum AuthLinkState { none, linkRequired, verifyingPassword, verifyingCode, linked, locked } // A14

enum ConsentStep { skip, umpForm, attPreprompt, attSystem, ready } // C01–C03

enum AdPersonalization { personalized, nonPersonalized, limited }

extension EngineX on Engine {
  String get label => this == Engine.local ? 'Local' : 'Cloud';
}

extension PlanX on Plan {
  String get label => this == Plan.free ? 'FREE' : 'PRO';
}
