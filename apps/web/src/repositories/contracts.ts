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
  LiveStatusResponse,
  OperationalSnapshotResponse,
  PaymentOrderListResponse,
  PaymentOrderResponse,
  PricingResponse,
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
} from "@/api/types";

export type ChannelStatus = "Recording" | "Waiting" | "Offline" | "Paused" | "Error";
export type RecordingStatus = "Recording" | "Processing" | "Ready" | "Error";
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
  backendStatus: WatchStatusValue;
  liveStatus: LiveStatusValue;
  source: Source;
  autoRecord: boolean;
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
  error?: string;
  partialDuration?: string;
  backendStatus: RecordingStatusValue;
  source: Source;
  actions: RecordingActions;
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
  | "quota_warning";

export type NotificationLink =
  | { to: "/recordings/$id" | "/channels/$id"; params: { id: string } }
  | { to: "/usage" };

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
  createArtifactDownloadUrl(artifactId: string): Promise<DownloadUrlResponse>;
  getLiveStatus(source: Source): Promise<LiveStatusResponse>;
  create(input: CreateRecordingRequest, idempotencyKey: string): Promise<RecordingResponse>;
  stop(id: string): Promise<RecordingResponse>;
  delete(id: string): Promise<void>;
}

export interface PricingRepository {
  get(): Promise<PricingResponse>;
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
  createCheckout(
    id: string,
    returnUrl: string,
    idempotencyKey: string,
  ): Promise<CheckoutResponse>;
}

export interface UsersRepository {
  getCurrent(): Promise<UserResponse>;
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
  listUsers(options?: PageOptions & { role?: string; isActive?: boolean }): Promise<AdminUserListResponse>;
  getUser(id: string): Promise<AdminUserResponse>;
  updateUser(
    id: string,
    input: { role?: "user" | "admin"; is_active?: boolean },
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
}

export type { SessionResponse };
