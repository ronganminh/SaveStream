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
  | "active"
  | "paused"
  | "paused_insufficient_credit"
  | "paused_error"
  | "disabled";

export type LiveStatusValue = "unknown" | "offline" | "live";

export type WatchResponse = {
  id: string;
  source: Source;
  creator: Creator | null;
  status: WatchStatusValue;
  live_status: LiveStatusValue;
  auto_record: boolean;
  last_checked_at: string | null;
  next_check_at: string | null;
  last_live_at: string | null;
  created_at: string;
  updated_at: string;
};

export type WatchListResponse = {
  items: WatchResponse[];
  pagination: Pagination;
};

export type CreateWatchRequest = {
  source: Source;
  auto_record: boolean;
};

export type UpdateWatchRequest = {
  auto_record?: boolean | null;
  status?: "active" | "paused" | "disabled" | null;
};

export type RecordingStatusValue =
  | "queued"
  | "resolving"
  | "waiting_live"
  | "recording"
  | "processing"
  | "uploading"
  | "completed"
  | "failed"
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
};

export type CreditTransactionResponse = {
  id: string;
  type: "grant" | "charge" | "release" | "adjustment" | "refund";
  amount: number;
  balance_after: number;
  reference_type: string;
  reference_id: string | null;
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
};

export type CreditPackageListResponse = {
  items: CreditPackageResponse[];
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

export type UserRole = "user" | "admin";

export type UserResponse = {
  id: string;
  role: UserRole;
  email: string;
  email_verified: boolean;
  display_name: string | null;
  locale: string;
  created_at: string;
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
  pending_outbox_events: number;
  unprocessed_payment_events: number;
  pending_payment_orders: number;
  paused_error_watches: number;
};
