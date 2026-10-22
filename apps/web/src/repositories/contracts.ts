import type {
  AdminCreditAdjustmentResponse,
  AdminPaymentListResponse,
  AdminRecordingListResponse,
  AdminRefundResponse,
  AdminRetryRecordingResponse,
  AdminUserListResponse,
  AdminUserResponse,
  ArtifactResponse,
  AuditLogListResponse,
  CheckoutResponse,
  CreateRecordingRequest,
  CreateWatchRequest,
  CreditBalanceResponse,
  CreditPackageListResponse,
  CreditReservationListResponse,
  CreditTransactionListResponse,
  DownloadUrlResponse,
  EntitlementResponse,
  LiveStatusResponse,
  OperationalSnapshotResponse,
  PaymentOrderListResponse,
  PaymentOrderResponse,
  PricingResponse,
  PublicPricingResponse,
  RecordingActions,
  RecordingEventResponse,
  RecordingResponse,
  RecordingStatusValue,
  SessionResponse,
  SessionsResponse,
  Source,
  UpdateWatchRequest,
  UserResponse,
  WatchListResponse,
  WatchResponse,
  WatchStatusValue,
  LiveStatusValue,
  NotificationPreferencesResponse,
  UpdateNotificationPreferencesRequest,
} from "@/api/types";

export type ChannelStatus = "Recording" | "Live" | "Waiting" | "Offline" | "Paused" | "Error";
export type RecordingStatus = "Recording" | "Processing" | "Waiting" | "Missed" | "Ready" | "Error";
export type Status = ChannelStatus | RecordingStatus;

export type ChannelModel = {
  id: string;
  name: string;
  handle: string;
  initials: string;
  platform: "tiktok";
  status: ChannelStatus;
  monitoring: boolean;
  live: string;
  checked: string;
  recordings: number;
  recordedHours: string;
  storage: string;
  tone: string;
  /** Creator avatar (cached copy or TikTok URL); render initials when null or broken. */
  avatarUrl?: string | null;
  backendStatus: WatchStatusValue;
  liveStatus: LiveStatusValue;
  source: Source;
  autoRecord: boolean;
  /** Set only while a recording job for this channel actually exists. */
  activeRecordingId?: string | null;
  /** Why a live channel is not being recorded (status "Live"). */
  liveReason?: string | null;
  /** Backend auto-record state, used to pick the fix for "LIVE · not recording". */
  autoRecordState?: "off" | "active" | "paused_no_cloud_minutes" | "waiting_for_cloud_slot" | null;
  /** Owner proved the channel is theirs (code in the TikTok bio). */
  ownerVerifiedAt?: string | null;
  /** Grace deadline for channels added before verification existed. */
  verificationDueAt?: string | null;
  /** SaveStream won't record this channel until it is verified. */
  verificationRequired?: boolean;
};

export type RecordingModel = {
  id: string;
  channelId: string;
  handle: string;
  title: string;
  date: string;
  time: string;
  duration: string;
  size: string;
  sizeGb: number;
  resolution: string;
  expires: string;
  expiresDays: number | null;
  expireTone?: "warning" | "critical";
  status: RecordingStatus;
  color: string;
  /** Real thumbnail (one frame); the gradient `color` shows when absent. */
  thumbnailUrl?: string | null;
  /** Creator avatar from the recording or its channel; initials/tone are the fallback. */
  avatarUrl?: string | null;
  initials?: string;
  tone?: string;
  /** User-facing failure text: the backend's failure_reason, else error.message. */
  error?: string;
  /** Backend failure_guidance for a failed or missed recording. */
  failureGuidance?: string;
  partialDuration?: string;
  backendStatus: RecordingStatusValue;
  source: Source;
  actions: RecordingActions;
  /** Seconds recorded so far (live) or in total. */
  durationSeconds?: number;
  /** Credits charged, or held so far while recording; null when unknown. */
  creditsUsed?: number | null;
  /** Backend error code of a failed recording, e.g. "UPLOAD_TIMEOUT". */
  errorCode?: string | null;
};

export type UsageSummary = {
  periodStart: string;
  periodEnd: string;
  resetsOn: string;
  recordingHours: { used: number; limit: number };
  downloadGb: { used: number; limit: number };
  channels: { used: number; limit: number };
  concurrent: { active: number; limit: number };
  retentionDays: number;
  storageGb: number;
};

export type UsageData = {
  summary: UsageSummary;
  dailyRecordingHours: readonly number[];
};

export type NotificationType =
  | "recording_started"
  | "recording_ready"
  | "recording_failed"
  | "quota_warning"
  | "cloud_minutes_exhausted"
  | "credits_low"
  | "channel_verification_needed";

export type NotificationLink =
  | { to: "/recordings/$id" | "/channels/$id"; params: { id: string } }
  | { to: "/usage" }
  | { to: "/channels" }
  | { to: "/billing" };

export type NotificationModel = {
  id: string;
  type: NotificationType;
  title: string;
  body: string;
  time: string;
  status: Status;
  read: boolean;
  link: NotificationLink;
};

export type NotificationPreferenceModel = NotificationPreferencesResponse;

export type PageOptions = {
  limit?: number;
  cursor?: string | null;
};

export type FilteredPageOptions = PageOptions & {
  status?: string | null;
};

export interface ChannelRepository {
  list(): Promise<ChannelModel[]>;
  getById(id: string): Promise<ChannelModel | null>;
  listWatches(options?: FilteredPageOptions): Promise<WatchListResponse>;
  getWatch(id: string): Promise<WatchResponse>;
  create(input: CreateWatchRequest): Promise<WatchResponse>;
  update(id: string, input: UpdateWatchRequest): Promise<WatchResponse>;
  pause(id: string): Promise<WatchResponse>;
  resume(id: string): Promise<WatchResponse>;
  delete(id: string): Promise<void>;
}

export interface RecordingRepository {
  list(): Promise<RecordingModel[]>;
  getById(id: string): Promise<RecordingModel | null>;
  getActive(): Promise<RecordingModel | null>;
  streamEvents(
    id: string,
    options?: { lastEventId?: string | null; signal?: AbortSignal },
  ): AsyncIterable<RecordingEventResponse>;
  listRecordings(options?: FilteredPageOptions): Promise<{
    items: RecordingResponse[];
    pagination: { next_cursor: string | null; has_more: boolean };
  }>;
  getRecording(id: string): Promise<RecordingResponse>;
  listArtifacts(id: string): Promise<ArtifactResponse[]>;
  /** `saveAs` signs an attachment disposition with a readable file name. */
  createArtifactDownloadUrl(
    artifactId: string,
    options?: { saveAs?: boolean },
  ): Promise<DownloadUrlResponse>;
  getLiveStatus(source: Source): Promise<LiveStatusResponse>;
  create(input: CreateRecordingRequest, idempotencyKey: string): Promise<RecordingResponse>;
  stop(id: string): Promise<RecordingResponse>;
  delete(id: string): Promise<void>;
}

export interface PricingRepository {
  get(): Promise<PricingResponse>;
  /** Unauthenticated catalog for the public pricing page. */
  getPublic(): Promise<PublicPricingResponse>;
}

export interface CreditsRepository {
  getBalance(): Promise<CreditBalanceResponse>;
  listTransactions(options?: PageOptions): Promise<CreditTransactionListResponse>;
  listReservations(options?: PageOptions): Promise<CreditReservationListResponse>;
}

export interface BillingRepository {
  listPackages(): Promise<CreditPackageListResponse>;
  createPaymentOrder(packageId: string, idempotencyKey: string): Promise<PaymentOrderResponse>;
  listPaymentOrders(options?: PageOptions): Promise<PaymentOrderListResponse>;
  getPaymentOrder(id: string): Promise<PaymentOrderResponse>;
  createCheckout(id: string, returnUrl: string, idempotencyKey: string): Promise<CheckoutResponse>;
  capturePaymentOrder(id: string, providerOrderId: string): Promise<PaymentOrderResponse>;
}

export interface UsersRepository {
  getCurrent(): Promise<UserResponse>;
  getEntitlement(): Promise<EntitlementResponse>;
  updateCurrent(input: {
    display_name?: string | null;
    locale?: string | null;
  }): Promise<UserResponse>;
  requestDeletion(): Promise<{ message: string }>;
  listSessions(): Promise<SessionsResponse>;
  revokeSession(id: string): Promise<void>;
  exportData(): Promise<unknown>;
}

export interface AdminRepository {
  listUsers(
    options?: PageOptions & { role?: string; isActive?: boolean },
  ): Promise<AdminUserListResponse>;
  getUser(id: string): Promise<AdminUserResponse>;
  updateUser(
    id: string,
    input: {
      role?: "user" | "owner" | "support" | "finance" | "admin";
      is_active?: boolean;
      reason?: string;
    },
  ): Promise<AdminUserResponse>;
  listRecordings(
    options?: FilteredPageOptions & { userId?: string },
  ): Promise<AdminRecordingListResponse>;
  getRecording(id: string): Promise<RecordingResponse>;
  retryRecording(id: string, idempotencyKey: string): Promise<AdminRetryRecordingResponse>;
  listPayments(
    options?: FilteredPageOptions & { userId?: string },
  ): Promise<AdminPaymentListResponse>;
  refundPayment(
    id: string,
    input: { amount_minor: number; credits: number },
    idempotencyKey: string,
  ): Promise<AdminRefundResponse>;
  adjustCredits(
    input: { user_id: string; amount: number; reason: string },
    idempotencyKey: string,
  ): Promise<AdminCreditAdjustmentResponse>;
  listAudit(
    options?: PageOptions & {
      actorUserId?: string;
      resourceType?: string;
      action?: string;
    },
  ): Promise<AuditLogListResponse>;
  getOperationalSnapshot(): Promise<OperationalSnapshotResponse>;
}

export interface UsageRepository {
  getCurrent(): Promise<UsageData>;
}

export interface NotificationRepository {
  list(): Promise<NotificationModel[]>;
  markRead(id: string): Promise<void>;
  markAllRead(): Promise<void>;
  getPreferences(): Promise<NotificationPreferenceModel>;
  updatePreferences(
    input: UpdateNotificationPreferencesRequest,
  ): Promise<NotificationPreferenceModel>;
}

export type SupportReportInput = {
  message: string;
  recording_id?: string | null;
  diagnostics?: Record<string, unknown>;
};

export interface SupportRepository {
  /** POST /v1/support/reports — shows up in /admin/reports. */
  createReport(input: SupportReportInput): Promise<{ report_id: string }>;
}

export interface SaveStreamRepositories {
  channels: ChannelRepository;
  recordings: RecordingRepository;
  pricing: PricingRepository;
  credits: CreditsRepository;
  billing: BillingRepository;
  users: UsersRepository;
  admin: AdminRepository;
  usage: UsageRepository;
  notifications: NotificationRepository;
  support: SupportRepository;
}

export type { SessionResponse };
