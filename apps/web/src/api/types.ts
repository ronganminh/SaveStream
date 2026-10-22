export type Pagination = {
  next_cursor: string | null;
  has_more: boolean;
};

export type Source = {
  type: "username" | "room_id" | "url";
  value: string;
};

export type Creator = {
  platform: "tiktok";
  username: string;
  display_name: string;
  avatar_url: string | null;
};

export type WatchStatusValue =
  "active" | "paused" | "paused_insufficient_credit" | "paused_error" | "disabled";

export type LiveStatusValue = "unknown" | "offline" | "live";

export type WatchResponse = {
  id: string;
  source: Source;
  creator: Creator | null;
  status: WatchStatusValue;
  live_status: LiveStatusValue;
  auto_record: boolean;
  auto_record_state?: "off" | "active" | "paused_no_cloud_minutes" | "waiting_for_cloud_slot";
  active_recording_id?: string | null;
  active_recording_status?: string | null;
  last_checked_at: string | null;
  next_check_at: string | null;
  last_live_at: string | null;
  created_at: string;
  updated_at: string;
  /** When the user confirmed they own, manage or may record the channel. */
  owner_attested_at?: string | null;
  /** Set once the owner proved the channel is theirs (code in the TikTok bio). */
  owner_verified_at?: string | null;
  /** Recording needs verification from this time (grace for older channels). */
  verification_due_at?: string | null;
  /** True when SaveStream won't record this channel until it is verified. */
  verification_required?: boolean;
  /** Bio code waiting to be checked; null once verified or with no unexpired code. */
  pending_verification_code?: string | null;
  pending_verification_expires_at?: string | null;
  /** The user's non-deleted recordings of this channel and their total length. */
  recording_count?: number | null;
  total_recorded_seconds?: number | null;
  /** Length of the most recent completed or stopped recording of this channel. */
  last_live_duration_seconds?: number | null;
};

export type ChannelVerificationResponse = {
  watch_id: string;
  verified: boolean;
  owner_verified_at: string | null;
  verification_due_at: string | null;
  verification_required: boolean;
  code: string | null;
  expires_at: string | null;
  checks_left: number;
  result?: "verified" | "code_not_found" | "retry_later" | null;
  retry_after_seconds?: number | null;
};

export type WatchListResponse = {
  items: WatchResponse[];
  pagination: Pagination;
};

export type EntitlementResponse = {
  plan: "free" | "pro";
  has_purchased: boolean;
  /** Older API builds omit these; fall back to plan === "pro". */
  email_verified?: boolean;
  can_auto_record?: boolean;
  trial_recording?: boolean;
  cloud_minutes_available: number;
  limits: {
    max_watches: number;
    max_concurrent_cloud_recordings: number;
    cloud_retention_days: number;
  };
  watch_count: number;
  local: {
    enabled: boolean;
    unlimited: boolean;
    daily_minutes: number;
    minutes_remaining: number;
    resets_at: string;
    rewards_used_today: number;
    rewards_cap_per_day: number;
    minutes_per_reward: number;
    extensions_cap_per_recording: number;
    max_concurrent_sessions: number;
    second_slot_expires_at: string | null;
  };
  updated_at: string;
};

export type CreateWatchRequest = {
  source: Source;
  auto_record: boolean;
  /** Optional "I own or manage this account, or have permission to record it." */
  owner_attested?: boolean;
};

export type UpdateWatchRequest = {
  auto_record?: boolean | null;
  status?: "active" | "paused" | "disabled" | null;
};

export type RecordingStatusValue =
  | "queued"
  | "resolving"
  | "waiting_live"
  | "waiting_for_cloud_slot"
  | "recording"
  | "processing"
  | "uploading"
  | "completed"
  | "failed"
  | "missed_no_cloud_slot"
  | "stop_requested"
  | "stopped";

export type RecordingActions = {
  can_stop: boolean;
  can_retry: boolean;
  can_delete: boolean;
};

export type RecordingError = {
  code: string;
  message: string;
  retryable: boolean;
};

export type RecordingResponse = {
  id: string;
  source: Source;
  creator: Creator | null;
  status: RecordingStatusValue;
  started_at: string | null;
  ended_at: string | null;
  duration_seconds: number;
  bytes_recorded: number;
  estimated_max_cost: number;
  actual_cost: number | null;
  credit_reservation_id: string | null;
  actions: RecordingActions;
  error: RecordingError | null;
  created_at: string;
  updated_at: string;
  engine?: "cloud";
  expires_at?: string | null;
  minutes_charged?: number;
  queue_position?: number | null;
  /** Signed URL of one JPEG frame; null until one exists. */
  thumbnail_url?: string | null;
};

export type RecordingListResponse = {
  items: RecordingResponse[];
  pagination: Pagination;
};

export type RecordingProgressData = {
  status: RecordingStatusValue;
  duration_seconds: number;
  bytes_recorded: number;
};

export type RecordingEventResponse = {
  id: string;
  sequence: number;
  type: string;
  recording_id: string;
  created_at: string;
  data: RecordingProgressData;
};

export type ArtifactResponse = {
  id: string;
  recording_id: string;
  kind: "video";
  container: "mp4";
  size_bytes: number;
  checksum_sha256: string;
  /** Probed from the finished file; null for older artifacts. */
  duration_ms?: number | null;
  width?: number | null;
  height?: number | null;
  created_at: string;
};

export type ArtifactsResponse = {
  items: ArtifactResponse[];
};

export type DownloadUrlResponse = {
  url: string;
  expires_at: string;
};

export type CreateRecordingRequest = {
  source: Source;
  max_duration_seconds?: number | null;
  quality?: "best";
  container?: "mp4";
};

export type LiveStatusResponse = {
  source: Source;
  creator: Creator | null;
  live_status: LiveStatusValue;
  room_id: string | null;
  checked_at: string;
};

export type PricingResponse = {
  version: string;
  credit_unit: "credit";
  rules: Array<Record<string, unknown>>;
};

export type CreditBalanceResponse = {
  posted: number;
  reserved: number;
  available: number;
  /** Store refund that came after the credits were spent; blocks recording. */
  refund_debt?: number;
};

export type CreditTransactionResponse = {
  id: string;
  type: "grant" | "charge" | "release" | "adjustment" | "refund";
  amount: number;
  balance_after: number;
  reference_type: string;
  reference_id: string | null;
  /** For a `release` entry: credits returned from the recording hold. */
  released_credits?: number | null;
  created_at: string;
};

export type CreditTransactionListResponse = {
  items: CreditTransactionResponse[];
  pagination: Pagination;
};

export type CreditReservationResponse = {
  id: string;
  recording_id: string;
  reserved: number;
  settled: number;
  released: number;
  status: "active" | "settled" | "released";
  created_at: string;
};

export type CreditReservationListResponse = {
  items: CreditReservationResponse[];
  pagination: Pagination;
};

export type Money = {
  amount_minor: number;
  currency: string;
};

export type CreditPackageResponse = {
  id: string;
  name: string;
  credits: number;
  price: Money;
  active: boolean;
  store_product_ids: {
    app_store: string | null;
    google_play: string | null;
  } | null;
  cloud_minutes: number | null;
};

export type CreditPackageListResponse = {
  items: CreditPackageResponse[];
};

export type PublicRecordingRate = {
  unit_seconds: number;
  credits_per_unit: number;
  minimum_credits: number;
};

export type PublicCreditPackageResponse = {
  id: string;
  code: string;
  name: string;
  credits: number;
  price: Money;
  recording_minutes: number | null;
};

export type PublicPricingResponse = {
  packages: PublicCreditPackageResponse[];
  recording_rate: PublicRecordingRate | null;
  signup_credits: number;
  max_channels_per_user: number | null;
  free_max_channels_per_user?: number | null;
  max_concurrent_recordings_per_user: number | null;
  recording_retention_days: number | null;
  trial_recording_retention_days: number | null;
  /** Purchase channels open right now (admin flag + provider readiness). */
  checkout?: { web: boolean; app_store: boolean; google_play: boolean };
};

export type PaymentStatusValue =
  | "created"
  | "pending"
  | "paid"
  | "failed"
  | "cancelled"
  | "expired"
  | "partially_refunded"
  | "refunded";

export type PaymentOrderResponse = {
  id: string;
  package_id: string;
  status: PaymentStatusValue;
  credits: number;
  amount: Money;
  provider: string | null;
  provider_reference: string | null;
  created_at: string;
  updated_at: string;
};

export type PaymentOrderListResponse = {
  items: PaymentOrderResponse[];
  pagination: Pagination;
};

export type CheckoutResponse = {
  checkout_url: string;
  payment_order: PaymentOrderResponse;
};

export type UserRole = "user" | "owner" | "support" | "finance" | "admin";

export type UserResponse = {
  id: string;
  role: UserRole;
  email: string;
  email_verified: boolean;
  display_name: string | null;
  locale: string;
  created_at: string;
  admin_mfa_enabled?: boolean;
  admin_mfa_verified?: boolean;
};

export type SessionResponse = {
  id: string;
  created_at: string;
  last_seen_at: string;
  current: boolean;
  user_agent: string | null;
  ip_hint: string | null;
};

export type SessionsResponse = {
  items: SessionResponse[];
};

export type AdminUserResponse = {
  id: string;
  email: string;
  display_name: string | null;
  role: UserRole;
  is_active: boolean;
  email_verified_at: string | null;
  deletion_requested_at: string | null;
  created_at: string;
  updated_at: string;
};

export type AdminUserListResponse = {
  items: AdminUserResponse[];
  pagination: Pagination;
};

export type AdminRecordingListResponse = {
  items: RecordingResponse[];
  pagination: Pagination;
};

export type AdminRetryRecordingResponse = {
  original_recording_id: string;
  recording: RecordingResponse;
};

export type AdminPaymentListResponse = {
  items: PaymentOrderResponse[];
  pagination: Pagination;
};

export type AdminRefundResponse = {
  id: string;
  payment_order_id: string;
  status: string;
  credits: number;
  amount_minor: number;
  provider: string | null;
  provider_refund_reference: string | null;
  created_at: string;
};

export type AdminCreditAdjustmentResponse = {
  transaction: CreditTransactionResponse;
};

export type AuditLogResponse = {
  id: string;
  actor_user_id: string | null;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  request_id: string | null;
  ip_address: string | null;
  user_agent: string | null;
  details: Record<string, unknown>;
  created_at: string;
};

export type AuditLogListResponse = {
  items: AuditLogResponse[];
  pagination: Pagination;
};

export type OperationalSnapshotResponse = {
  active_recordings: number;
  failed_recordings_recent: number;
  failed_recordings_window_seconds?: number;
  pending_outbox_events: number;
  unprocessed_payment_events: number;
  pending_payment_orders: number;
  paused_error_watches: number;
};

export type NotificationTypeValue =
  | "recording_started"
  | "recording_ready"
  | "recording_failed"
  | "cloud_minutes_exhausted"
  | "credits_low"
  | "channel_verification_needed";

export type NotificationResponse = {
  id: string;
  type: NotificationTypeValue;
  title: string;
  body: string;
  read: boolean;
  resource_type: "recording" | "watch" | null;
  resource_id: string | null;
  created_at: string;
};

export type NotificationListResponse = {
  items: NotificationResponse[];
  pagination: Pagination;
};

/** Email copies of notifications; each email also has an unsubscribe link. */
export type EmailPreferenceKey =
  | "email_creator_live"
  | "email_recording_ready"
  | "email_recording_failed"
  | "email_recording_expiring"
  | "email_credits_low"
  | "email_credits_exhausted";

export type NotificationPreferencesResponse = {
  recording_started: boolean;
  recording_ready: boolean;
  recording_failed: boolean;
  email_supported: boolean;
  updated_at: string | null;
} & Partial<Record<EmailPreferenceKey, boolean>>;

export type UpdateNotificationPreferencesRequest = {
  recording_started?: boolean;
  recording_ready?: boolean;
  recording_failed?: boolean;
} & Partial<Record<EmailPreferenceKey, boolean>>;

export type MarkAllNotificationsReadResponse = {
  updated: number;
};
