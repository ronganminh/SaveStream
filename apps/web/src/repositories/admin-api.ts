import { apiClient } from "@/api/client";
import type {
  CreditTransactionResponse,
  PaymentOrderResponse,
  RecordingResponse,
  WatchResponse,
} from "@/api/types";

export type AdminRole = "owner" | "support" | "finance";
export type AdminRoleWithLegacy = AdminRole | "admin";

export type AdminMfaStatus = {
  enabled: boolean;
  verified: boolean;
};

export type AdminMfaSetup = {
  secret: string;
  otpauth_uri: string;
  qr_svg: string;
  recovery_codes: string[];
};

export type AdminStepUpResponse = {
  token: string;
  expires_at: string;
};

export type AdminUser = {
  id: string;
  email: string;
  display_name: string | null;
  role: "user" | AdminRoleWithLegacy;
  is_active: boolean;
  email_verified_at: string | null;
  deletion_requested_at: string | null;
  created_at: string;
  updated_at: string;
  plan?: "free" | "pro" | null;
  cloud_minutes_available?: number | null;
  latest_purchase_provider?: string | null;
};

type Pagination = {
  next_cursor: string | null;
  has_more: boolean;
};

export type AdminListResponse = {
  items: AdminUser[];
  pagination: Pagination;
};

export type AdminUserFilters = {
  cursor?: string | null | undefined;
  query?: string | undefined;
  plan?: "free" | "pro" | "" | undefined;
  accountStatus?: "active" | "locked" | "pending_deletion" | "deleted" | "" | undefined;
  emailVerified?: "true" | "false" | "" | undefined;
  createdFrom?: string | undefined;
  createdTo?: string | undefined;
  purchaseProvider?: string | undefined;
  sortBy?: "created_at" | "email" | undefined;
  sortOrder?: "asc" | "desc" | undefined;
};

export type AdminEntitlement = {
  plan: "free" | "pro";
  has_purchased: boolean;
  cloud_minutes_available: number;
  max_watches: number;
  max_concurrent_cloud_recordings: number;
  cloud_retention_days: number;
  watch_count: number;
};

export type AdminUserSession = {
  id: string;
  client_type: string;
  user_agent: string | null;
  ip_hint: string | null;
  created_at: string;
  last_seen_at: string;
  expires_at: string;
  revoked_at: string | null;
  revoked_reason: string | null;
};

export type AdminUserNotification = {
  id: string;
  kind: string;
  title: string;
  body: string;
  resource_type: string | null;
  resource_id: string | null;
  read_at: string | null;
  created_at: string;
};

export type AdminUserNote = {
  id: string;
  user_id: string;
  author_user_id: string | null;
  body: string;
  created_at: string;
  updated_at: string;
};

export type AdminAuditEntry = {
  id: string;
  actor_user_id: string | null;
  action: string;
  resource_type: string | null;
  resource_id: string | null;
  request_id: string | null;
  ip_address: string | null;
  user_agent: string | null;
  actor_role: string | null;
  reason: string | null;
  before_state: Record<string, unknown> | null;
  after_state: Record<string, unknown> | null;
  details: Record<string, unknown>;
  created_at: string;
};

export type AdminUserDetail = {
  user: AdminUser;
  entitlement: AdminEntitlement;
  balance: { posted: number; reserved: number; available: number };
  watches: WatchResponse[];
  recordings: RecordingResponse[];
  payments: PaymentOrderResponse[];
  ledger: CreditTransactionResponse[];
  sessions: AdminUserSession[];
  notifications: AdminUserNotification[];
  notes: AdminUserNote[];
  audit: AdminAuditEntry[];
};

export type AdminViewAsUser = Pick<
  AdminUserDetail,
  "user" | "entitlement" | "balance" | "watches" | "recordings"
>;

export type AdminPrivacyRequest = {
  id: string;
  user_id: string;
  email: string;
  kind: "delete" | "export";
  status: "pending" | "completed" | "cancelled";
  requested_at: string;
  completed_at: string | null;
  cancelled_at: string | null;
};

export type AdminSearchHit = {
  type: "user" | "payment_order" | "recording" | "request";
  id: string;
  label: string;
  detail: string | null;
  href: string;
};

function stepUpHeaders(token: string): HeadersInit {
  return { "X-Admin-Step-Up": token };
}

export const adminFoundationApi = {
  listUsers(filters: AdminUserFilters = {}) {
    const query = new URLSearchParams({ limit: "50" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.query) query.set("query", filters.query);
    if (filters.plan) query.set("plan", filters.plan);
    if (filters.accountStatus) query.set("account_status", filters.accountStatus);
    if (filters.emailVerified) query.set("email_verified", filters.emailVerified);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    if (filters.purchaseProvider) query.set("purchase_provider", filters.purchaseProvider);
    query.set("sort_by", filters.sortBy ?? "created_at");
    query.set("sort_order", filters.sortOrder ?? "desc");
    return apiClient.get<AdminListResponse>(`/v1/admin/users?${query.toString()}`);
  },

  exportUsers(filters: AdminUserFilters = {}) {
    const query = new URLSearchParams();
    if (filters.query) query.set("query", filters.query);
    if (filters.plan) query.set("plan", filters.plan);
    if (filters.accountStatus) query.set("account_status", filters.accountStatus);
    if (filters.emailVerified) query.set("email_verified", filters.emailVerified);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    if (filters.purchaseProvider) query.set("purchase_provider", filters.purchaseProvider);
    query.set("sort_by", filters.sortBy ?? "created_at");
    query.set("sort_order", filters.sortOrder ?? "desc");
    return apiClient.get<string>(`/v1/admin/users/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  getUserDetail(userId: string) {
    return apiClient.get<AdminUserDetail>(`/v1/admin/users/${userId}/detail`);
  },

  resendVerification(userId: string, reason: string) {
    return apiClient.post<{ message: string }>(`/v1/admin/users/${userId}/resend-verification`, {
      json: { reason },
    });
  },

  forcePasswordReset(userId: string, reason: string) {
    return apiClient.post<{ message: string }>(`/v1/admin/users/${userId}/force-password-reset`, {
      json: { reason },
    });
  },

  forceLogout(userId: string, reason: string) {
    return apiClient.post<{ message: string }>(`/v1/admin/users/${userId}/force-logout`, {
      json: { reason },
    });
  },

  updateUserProfile(userId: string, displayName: string | null, reason: string) {
    return apiClient.patch<AdminUser>(`/v1/admin/users/${userId}/profile`, {
      json: { display_name: displayName, reason },
    });
  },

  updateUserStatus(
    userId: string,
    isActive: boolean,
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.patch<AdminUser>(`/v1/admin/users/${userId}`, {
      json: { is_active: isActive, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  createUserNote(userId: string, body: string, reason: string) {
    return apiClient.post<AdminUserNote>(`/v1/admin/users/${userId}/notes`, {
      json: { body, reason },
    });
  },

  updateUserNote(userId: string, noteId: string, body: string, reason: string) {
    return apiClient.patch<AdminUserNote>(`/v1/admin/users/${userId}/notes/${noteId}`, {
      json: { body, reason },
    });
  },

  search(query: string) {
    const params = new URLSearchParams({ q: query });
    return apiClient.get<{ items: AdminSearchHit[] }>(`/v1/admin/search?${params.toString()}`);
  },

  listPrivacyRequests() {
    return apiClient.get<{ items: AdminPrivacyRequest[] }>("/v1/admin/privacy/requests?limit=100");
  },

  exportPrivacyData(userId: string, reason: string) {
    return apiClient.post<Record<string, unknown>>(`/v1/admin/users/${userId}/privacy/export`, {
      json: { reason },
    });
  },

  cancelDeletion(userId: string, reason: string, stepUpToken: string) {
    return apiClient.post<{ message: string }>(
      `/v1/admin/users/${userId}/privacy/deletion/cancel`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },

  performDeletion(userId: string, reason: string, stepUpToken: string) {
    return apiClient.post<{ message: string }>(
      `/v1/admin/users/${userId}/privacy/deletion/perform`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },

  viewAsUser(userId: string, reason: string) {
    const params = new URLSearchParams({ reason });
    return apiClient.get<AdminViewAsUser>(
      `/v1/admin/users/${userId}/view?${params.toString()}`,
    );
  },

  getMfaStatus() {
    return apiClient.get<AdminMfaStatus>("/v1/admin/security/mfa");
  },

  beginMfaSetup() {
    return apiClient.post<AdminMfaSetup>("/v1/admin/security/mfa/setup", {
      json: {},
    });
  },

  enableMfa(code: string) {
    return apiClient.post<AdminMfaStatus>("/v1/admin/security/mfa/enable", {
      json: { code },
    });
  },

  verifyMfa(code: string) {
    return apiClient.post<AdminMfaStatus>("/v1/admin/security/mfa/verify", {
      json: { code },
    });
  },

  stepUp(password: string, totpCode: string) {
    return apiClient.post<AdminStepUpResponse>("/v1/admin/step-up", {
      json: { password, totp_code: totpCode },
    });
  },

  listAdmins(cursor?: string | null) {
    const query = new URLSearchParams({ limit: "100" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<AdminListResponse>(`/v1/admin/admins?${query.toString()}`);
  },

  updateAdminRole(
    userId: string,
    role: "user" | AdminRole,
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.patch<AdminUser>(`/v1/admin/admins/${userId}`, {
      json: { role, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  resetAdminMfa(userId: string, reason: string, stepUpToken: string) {
    return apiClient.post<AdminUser>(`/v1/admin/admins/${userId}/mfa/reset`, {
      json: { reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },
};


export type AdminStorageRun = {
  id: string;
  kind: string;
  status: string;
  scanned_count: number;
  orphan_count: number;
  deleted_count: number;
  orphan_keys: string[];
  truncated: boolean;
  error: string | null;
  created_at: string;
  started_at: string | null;
  completed_at: string | null;
};

export type AdminStorageSummary = {
  total_bytes: number;
  by_user: Array<{ user_id: string; email: string; bytes: number }>;
  daily_trend: Array<{ day: string; bytes: number }>;
  latest_cleanup: {
    run_id: string;
    created_at: string;
    deleted_count: number;
    scanned_count: number;
  } | null;
};

export type AdminEmailLog = {
  id: string;
  user_id: string | null;
  recipient_email: string;
  kind: string;
  subject: string;
  status: string;
  error: string | null;
  attempts: number;
  sent_at: string | null;
  created_at: string;
};

export type AdminEmailTemplate = {
  key: "verify_email" | "password_reset";
  subject: string;
  body: string;
  overridden: boolean;
  updated_at: string | null;
};

export type AdminBroadcast = {
  id: string;
  kind: "system" | "marketing";
  title: string;
  body: string;
  channels: Array<"in_app" | "push" | "email">;
  status: string;
  audience_count: number;
  delivered_in_app: number;
  delivered_push: number;
  delivered_email: number;
  failed_count: number;
  reason: string;
  created_at: string;
  started_at: string | null;
  completed_at: string | null;
};

export type AdminEmailFilters = {
  cursor?: string | null;
  recipient?: string;
  kind?: string;
  status?: string;
  sortOrder?: "asc" | "desc";
};

export type AdminBroadcastFilters = {
  cursor?: string | null;
  query?: string;
  kind?: "" | "system" | "marketing";
  status?: string;
  sortOrder?: "asc" | "desc";
};


export type AdminPaymentChannel = "web" | "app_store" | "google_play";
export type AdminPaymentOrder = {
  id: string;
  user_id: string;
  user_email: string;
  package_id: string;
  package_code: string;
  package_name: string;
  status:
    | "created"
    | "pending"
    | "paid"
    | "failed"
    | "cancelled"
    | "expired"
    | "partially_refunded"
    | "refunded";
  purchase_channel: AdminPaymentChannel;
  provider: string | null;
  provider_transaction_id: string | null;
  credits: number;
  amount_minor: number;
  currency: string;
  refunded_credits: number;
  refunded_amount_minor: number;
  gross_usd_minor: number | null;
  estimated_store_fee_minor: number | null;
  estimated_store_fee_rate_bps: number | null;
  refund_mode: "admin_web" | "store_managed";
  paid_at: string | null;
  created_at: string;
  updated_at: string;
};

export type AdminPaymentFilters = {
  cursor?: string | null;
  query?: string;
  status?: string;
  channel?: "" | AdminPaymentChannel;
  packageId?: string;
  createdFrom?: string;
  createdTo?: string;
  sortOrder?: "asc" | "desc";
};

export type AdminPaymentDetail = {
  order: AdminPaymentOrder;
  timeline: Array<{
    at: string;
    event: string;
    status: string | null;
    detail: string | null;
  }>;
};

export type AdminRefundPreview = {
  payment_order_id: string;
  amount_minor: number;
  corresponding_credits: number;
  deducted_credits: number;
  balance_available: number;
  remaining_refundable_amount_minor: number;
  remaining_refundable_credits: number;
};

export type AdminStuckPayment = {
  order: AdminPaymentOrder;
  reason: "pending_too_long" | "paid_missing_credit";
};

export type AdminLedgerCategory = "purchase" | "spend" | "refund" | "adjustment" | "gift";
export type AdminLedgerEntry = {
  id: string;
  user_id: string;
  user_email: string;
  category: AdminLedgerCategory;
  type: string;
  amount: number;
  balance_after: number;
  reference_type: string;
  reference_id: string | null;
  reason: string | null;
  counts_as_purchase: boolean;
  created_at: string;
};

export type AdminLedgerFilters = {
  cursor?: string | null;
  userId?: string;
  category?: "" | AdminLedgerCategory;
  createdFrom?: string;
  createdTo?: string;
  sortOrder?: "asc" | "desc";
};

export type AdminStuckReservation = {
  id: string;
  user_id: string;
  recording_id: string;
  recording_status: string;
  reserved: number;
  settled: number;
  released: number;
  remaining_reserved: number;
  created_at: string;
};

export const adminFinanceApi = {
  listPayments(filters: AdminPaymentFilters = {}) {
    const query = new URLSearchParams({ limit: "50", sort_order: filters.sortOrder ?? "desc" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.query) query.set("query", filters.query);
    if (filters.status) query.set("status", filters.status);
    if (filters.channel) query.set("channel", filters.channel);
    if (filters.packageId) query.set("package_id", filters.packageId);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    return apiClient.get<{ items: AdminPaymentOrder[]; pagination: Pagination }>(
      `/v1/admin/payments?${query.toString()}`,
    );
  },

  paymentDetail(orderId: string) {
    return apiClient.get<AdminPaymentDetail>(`/v1/admin/payments/${orderId}`);
  },

  exportPayments(filters: AdminPaymentFilters = {}) {
    const query = new URLSearchParams({ sort_order: filters.sortOrder ?? "desc" });
    if (filters.query) query.set("query", filters.query);
    if (filters.status) query.set("status", filters.status);
    if (filters.channel) query.set("channel", filters.channel);
    if (filters.packageId) query.set("package_id", filters.packageId);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    return apiClient.get<string>(`/v1/admin/payments/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  refundPreview(orderId: string, amountMinor: number) {
    return apiClient.get<AdminRefundPreview>(
      `/v1/admin/payments/${orderId}/refund-preview?amount_minor=${amountMinor}`,
    );
  },

  refund(
    orderId: string,
    amountMinor: number,
    credits: number,
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.post<{
      id: string;
      payment_order_id: string;
      status: string;
      credits: number;
      amount_minor: number;
    }>(`/v1/admin/payments/${orderId}/refunds`, {
      json: { amount_minor: amountMinor, credits, reason },
      headers: {
        ...stepUpHeaders(stepUpToken),
        "Idempotency-Key": crypto.randomUUID(),
      },
    });
  },

  stuckPayments(cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<{ items: AdminStuckPayment[]; pagination: Pagination }>(
      `/v1/admin/payments/stuck?${query.toString()}`,
    );
  },

  reconcilePayment(orderId: string, reason: string, stepUpToken: string) {
    return apiClient.post<{ payment_order_id: string; action: string; status: string }>(
      `/v1/admin/payments/${orderId}/reconcile`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },

  listLedger(filters: AdminLedgerFilters = {}) {
    const query = new URLSearchParams({ limit: "50", sort_order: filters.sortOrder ?? "desc" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.userId) query.set("user_id", filters.userId);
    if (filters.category) query.set("category", filters.category);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    return apiClient.get<{ items: AdminLedgerEntry[]; pagination: Pagination }>(
      `/v1/admin/credits/ledger?${query.toString()}`,
    );
  },

  exportLedger(filters: AdminLedgerFilters = {}) {
    const query = new URLSearchParams({ sort_order: filters.sortOrder ?? "desc" });
    if (filters.userId) query.set("user_id", filters.userId);
    if (filters.category) query.set("category", filters.category);
    if (filters.createdFrom) query.set("created_from", new Date(filters.createdFrom).toISOString());
    if (filters.createdTo) query.set("created_to", new Date(filters.createdTo).toISOString());
    return apiClient.get<string>(`/v1/admin/credits/ledger/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  adjustCredits(
    userId: string,
    amount: number,
    reason: string,
    countsAsPurchase: boolean,
    stepUpToken: string,
  ) {
    return apiClient.post<{ transaction: CreditTransactionResponse }>(
      "/v1/admin/credits/adjustments",
      {
        json: {
          user_id: userId,
          amount,
          reason,
          counts_as_purchase: countsAsPurchase,
        },
        headers: {
          "X-Admin-Step-Up": stepUpToken,
          "Idempotency-Key": crypto.randomUUID(),
        },
      },
    );
  },

  stuckReservations(cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<{ items: AdminStuckReservation[]; pagination: Pagination }>(
      `/v1/admin/credits/stuck-reservations?${query.toString()}`,
    );
  },

  releaseReservation(reservationId: string, reason: string, stepUpToken: string) {
    return apiClient.post<{ reservation: AdminStuckReservation; released_credits: number }>(
      `/v1/admin/credits/stuck-reservations/${reservationId}/release`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },
};


export type AdminCatalogPackage = {
  id: string;
  code: string;
  name: string;
  credits: number;
  amount_minor: number;
  currency: "USD";
  active: boolean;
  display_order: number;
  app_store_product_id: string | null;
  google_play_product_id: string | null;
  web_variant_id: string | null;
  order_count: number;
  created_at: string;
  updated_at: string;
};

export type AdminPromotion = {
  id: string;
  code: string;
  credits: number;
  expires_at: string | null;
  max_redemptions: number | null;
  redemption_count: number;
  active: boolean;
  counts_as_purchase: boolean;
  created_at: string;
  updated_at: string;
};

export type AdminPromotionRedemption = {
  id: string;
  user_id: string;
  user_email: string;
  ledger_entry_id: string | null;
  created_at: string;
};

export type AdminBulkGrantFilters = {
  query?: string;
  plan?: "" | "free" | "pro";
  account_status?: "" | "active" | "locked" | "pending_deletion" | "deleted";
  email_verified?: "" | "true" | "false";
  created_from?: string;
  created_to?: string;
  purchase_provider?: string;
};

export type AdminBulkGrant = {
  id: string;
  credits: number;
  counts_as_purchase: boolean;
  reason: string;
  filters: Record<string, unknown>;
  status: "queued" | "running" | "completed" | "failed";
  audience_count: number;
  total_credits: number;
  delivered_count: number;
  failed_count: number;
  error: string | null;
  created_at: string;
  started_at: string | null;
  completed_at: string | null;
};

export type AdminBulkGrantDelivery = {
  id: string;
  user_id: string;
  user_email: string;
  ledger_entry_id: string | null;
  status: "queued" | "delivered" | "failed";
  error: string | null;
  created_at: string;
  updated_at: string;
};

function bulkFiltersPayload(filters: AdminBulkGrantFilters) {
  return {
    ...(filters.query ? { query: filters.query } : {}),
    ...(filters.plan ? { plan: filters.plan } : {}),
    ...(filters.account_status ? { account_status: filters.account_status } : {}),
    ...(filters.email_verified
      ? { email_verified: filters.email_verified === "true" }
      : {}),
    ...(filters.created_from
      ? { created_from: new Date(filters.created_from).toISOString() }
      : {}),
    ...(filters.created_to
      ? { created_to: new Date(filters.created_to).toISOString() }
      : {}),
    ...(filters.purchase_provider
      ? { purchase_provider: filters.purchase_provider }
      : {}),
  };
}

export const adminCatalogApi = {
  listPackages() {
    return apiClient.get<{ items: AdminCatalogPackage[] }>("/v1/admin/packages");
  },

  createPackage(
    payload: {
      code: string;
      name: string;
      credits: number;
      amount_minor: number;
      display_order: number;
      app_store_product_id?: string | null;
      google_play_product_id?: string | null;
      web_variant_id?: string | null;
    },
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.post<AdminCatalogPackage>("/v1/admin/packages", {
      json: { ...payload, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  updatePackage(
    packageId: string,
    payload: {
      name?: string;
      credits?: number;
      amount_minor?: number;
      display_order?: number;
      active?: boolean;
      app_store_product_id?: string | null;
      google_play_product_id?: string | null;
      web_variant_id?: string | null;
      clear_app_store_product_id?: boolean;
      clear_google_play_product_id?: boolean;
      clear_web_variant_id?: boolean;
    },
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.request<AdminCatalogPackage>(`/v1/admin/packages/${packageId}`, {
      method: "PATCH",
      json: { ...payload, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  listPromotions() {
    return apiClient.get<{ items: AdminPromotion[] }>("/v1/admin/promotions");
  },

  createPromotion(
    payload: {
      code: string;
      credits: number;
      expires_at?: string | null;
      max_redemptions?: number | null;
      counts_as_purchase: boolean;
    },
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.post<AdminPromotion>("/v1/admin/promotions", {
      json: { ...payload, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  updatePromotion(
    promotionId: string,
    payload: {
      credits?: number;
      expires_at?: string | null;
      clear_expires_at?: boolean;
      max_redemptions?: number | null;
      clear_max_redemptions?: boolean;
      active?: boolean;
      counts_as_purchase?: boolean;
    },
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.request<AdminPromotion>(`/v1/admin/promotions/${promotionId}`, {
      method: "PATCH",
      json: { ...payload, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  promotionRedemptions(promotionId: string, cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<{
      items: AdminPromotionRedemption[];
      pagination: Pagination;
    }>(`/v1/admin/promotions/${promotionId}/redemptions?${query.toString()}`);
  },

  previewBulkGrant(credits: number, filters: AdminBulkGrantFilters) {
    return apiClient.post<{
      audience_count: number;
      credits_per_user: number;
      total_credits: number;
    }>("/v1/admin/bulk-grants/preview", {
      json: { credits, filters: bulkFiltersPayload(filters) },
    });
  },

  createBulkGrant(
    credits: number,
    filters: AdminBulkGrantFilters,
    countsAsPurchase: boolean,
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.post<AdminBulkGrant>("/v1/admin/bulk-grants", {
      json: {
        credits,
        filters: bulkFiltersPayload(filters),
        counts_as_purchase: countsAsPurchase,
        reason,
      },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  getBulkGrant(grantId: string) {
    return apiClient.get<AdminBulkGrant>(`/v1/admin/bulk-grants/${grantId}`);
  },

  bulkGrantDeliveries(grantId: string, cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<{
      items: AdminBulkGrantDelivery[];
      pagination: Pagination;
    }>(`/v1/admin/bulk-grants/${grantId}/deliveries?${query.toString()}`);
  },
};

export const adminOperationsApi = {
  storageSummary() {
    return apiClient.get<AdminStorageSummary>("/v1/admin/storage/summary");
  },

  createOrphanScan(limit: number, reason: string) {
    return apiClient.post<AdminStorageRun>("/v1/admin/storage/orphan-scans", {
      json: { limit, reason },
    });
  },

  getStorageRun(runId: string) {
    return apiClient.get<AdminStorageRun>(`/v1/admin/storage/runs/${runId}`);
  },

  deleteOrphans(runId: string, reason: string, stepUpToken: string) {
    return apiClient.post<AdminStorageRun>(
      `/v1/admin/storage/orphan-scans/${runId}/delete`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },

  listEmailLogs(filters: AdminEmailFilters = {}) {
    const query = new URLSearchParams({ limit: "50", sort_order: filters.sortOrder ?? "desc" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.recipient) query.set("recipient", filters.recipient);
    if (filters.kind) query.set("kind", filters.kind);
    if (filters.status) query.set("status", filters.status);
    return apiClient.get<{ items: AdminEmailLog[]; pagination: Pagination }>(
      `/v1/admin/email/logs?${query.toString()}`,
    );
  },

  exportEmailLogs(filters: AdminEmailFilters = {}) {
    const query = new URLSearchParams({ sort_order: filters.sortOrder ?? "desc" });
    if (filters.recipient) query.set("recipient", filters.recipient);
    if (filters.kind) query.set("kind", filters.kind);
    if (filters.status) query.set("status", filters.status);
    return apiClient.get<string>(`/v1/admin/email/logs/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  resendEmail(logId: string, reason: string) {
    return apiClient.post<AdminEmailLog>(`/v1/admin/email/logs/${logId}/resend`, {
      json: { reason },
    });
  },

  listEmailTemplates() {
    return apiClient.get<AdminEmailTemplate[]>("/v1/admin/email/templates");
  },

  previewEmailTemplate(key: AdminEmailTemplate["key"]) {
    return apiClient.get<{ subject: string; text: string; html: string }>(
      `/v1/admin/email/templates/${key}/preview`,
    );
  },

  updateEmailTemplate(
    key: AdminEmailTemplate["key"],
    subject: string,
    body: string,
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.request<AdminEmailTemplate>(`/v1/admin/email/templates/${key}`, {
      method: "PUT",
      json: { subject, body, reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  resetEmailTemplate(
    key: AdminEmailTemplate["key"],
    reason: string,
    stepUpToken: string,
  ) {
    return apiClient.delete<{ message: string }>(`/v1/admin/email/templates/${key}`, {
      json: { reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  testEmailTemplate(key: AdminEmailTemplate["key"], reason: string) {
    return apiClient.post<AdminEmailLog>(`/v1/admin/email/templates/${key}/test`, {
      json: { reason },
    });
  },

  previewBroadcast(kind: "system" | "marketing", channels: AdminBroadcast["channels"]) {
    return apiClient.post<{
      audience_count: number;
      kind: "system" | "marketing";
      channels: AdminBroadcast["channels"];
    }>("/v1/admin/broadcasts/preview", { json: { kind, channels } });
  },

  listBroadcasts(filters: AdminBroadcastFilters = {}) {
    const query = new URLSearchParams({ limit: "50", sort_order: filters.sortOrder ?? "desc" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.query) query.set("query", filters.query);
    if (filters.kind) query.set("kind", filters.kind);
    if (filters.status) query.set("status", filters.status);
    return apiClient.get<{ items: AdminBroadcast[]; pagination: Pagination }>(
      `/v1/admin/broadcasts?${query.toString()}`,
    );
  },

  exportBroadcasts(filters: AdminBroadcastFilters = {}) {
    const query = new URLSearchParams({ sort_order: filters.sortOrder ?? "desc" });
    if (filters.query) query.set("query", filters.query);
    if (filters.kind) query.set("kind", filters.kind);
    if (filters.status) query.set("status", filters.status);
    return apiClient.get<string>(`/v1/admin/broadcasts/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  getBroadcast(broadcastId: string) {
    return apiClient.get<AdminBroadcast>(`/v1/admin/broadcasts/${broadcastId}`);
  },

  createBroadcast(
    payload: {
      kind: "system" | "marketing";
      channels: AdminBroadcast["channels"];
      title: string;
      body: string;
      reason: string;
    },
    stepUpToken: string,
  ) {
    return apiClient.post<AdminBroadcast>("/v1/admin/broadcasts", {
      json: payload,
      headers: stepUpHeaders(stepUpToken),
    });
  },
};


export type AdminRecordingFilters = {
  cursor?: string | null;
  userId?: string;
  channel?: string;
  status?: string;
  createdFrom?: string;
  createdTo?: string;
  sortOrder?: "asc" | "desc";
};

export type AdminPlaybackAccess = {
  url: string;
  expires_at: string;
  artifact_id: string;
};

export type AdminQueueItem = {
  recording_id: string;
  user_id: string;
  user_email: string;
  channel: string;
  waiting_since: string;
  queue_position: number;
};

export type AdminQueue = {
  items: AdminQueueItem[];
  missed_today: number;
  next_cursor: string | null;
  has_more: boolean;
};

export type AdminWatchChannel = {
  source_type: string;
  channel: string;
  followers: number;
  auto_record_count: number;
  paused_count: number;
  failing_count: number;
  max_failure_count: number;
  last_checked_at: string | null;
  last_error: string | null;
};

export type AdminDetectorHourly = {
  hour: string;
  checks: number;
  failures: number;
  failure_rate: number | null;
  average_latency_ms: number | null;
};

export type AdminDetectorMetrics = {
  last_run_at: string | null;
  last_latency_ms: number | null;
  average_latency_ms_1h: number | null;
  failure_rate_1h: number | null;
  hourly: AdminDetectorHourly[];
};

export type AdminCapacityHourly = {
  hour: string;
  max_concurrent: number;
  limit: number;
};

export type AdminCapacity = {
  current_in_use: number;
  global_limit: number;
  hourly: AdminCapacityHourly[];
};

function adminRecordingQuery(filters: AdminRecordingFilters = {}) {
  const query = new URLSearchParams({
    limit: "50",
    sort_order: filters.sortOrder ?? "desc",
  });
  if (filters.cursor) query.set("cursor", filters.cursor);
  if (filters.userId) query.set("user_id", filters.userId);
  if (filters.channel) query.set("channel", filters.channel);
  if (filters.status) query.set("status", filters.status);
  if (filters.createdFrom) {
    query.set("created_from", new Date(filters.createdFrom).toISOString());
  }
  if (filters.createdTo) {
    query.set("created_to", new Date(filters.createdTo).toISOString());
  }
  return query;
}

export const adminRecordingOpsApi = {
  listRecordings(filters: AdminRecordingFilters = {}) {
    return apiClient.get<{ items: RecordingResponse[]; pagination: Pagination }>(
      `/v1/admin/recordings?${adminRecordingQuery(filters).toString()}`,
    );
  },

  exportRecordings(filters: AdminRecordingFilters = {}) {
    const query = adminRecordingQuery(filters);
    query.delete("limit");
    return apiClient.get<string>(`/v1/admin/recordings/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  stop(recordingId: string, reason: string) {
    return apiClient.post<RecordingResponse>(`/v1/admin/recordings/${recordingId}/stop`, {
      json: { reason },
    });
  },

  retry(recordingId: string) {
    return apiClient.post<{ original_recording_id: string; recording: RecordingResponse }>(
      `/v1/admin/recordings/${recordingId}/retry`,
      { headers: { "Idempotency-Key": crypto.randomUUID() } },
    );
  },

  delete(recordingId: string, reason: string, stepUpToken: string) {
    return apiClient.delete<void>(`/v1/admin/recordings/${recordingId}`, {
      json: { reason },
      headers: stepUpHeaders(stepUpToken),
    });
  },

  extendRetention(recordingId: string, expiresAt: string, reason: string) {
    return apiClient.patch<RecordingResponse>(
      `/v1/admin/recordings/${recordingId}/retention`,
      { json: { expires_at: new Date(expiresAt).toISOString(), reason } },
    );
  },

  requestPlayback(recordingId: string, reason: string, stepUpToken: string) {
    return apiClient.post<AdminPlaybackAccess>(
      `/v1/admin/recordings/${recordingId}/playback-access`,
      { json: { reason }, headers: stepUpHeaders(stepUpToken) },
    );
  },

  queue(cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<AdminQueue>(`/v1/admin/recording-queue?${query.toString()}`);
  },

  watchChannels(cursor?: string | null) {
    const query = new URLSearchParams({ limit: "50" });
    if (cursor) query.set("cursor", cursor);
    return apiClient.get<{
      items: AdminWatchChannel[];
      next_cursor: string | null;
      has_more: boolean;
    }>(`/v1/admin/watches/channels?${query.toString()}`);
  },

  detectorMetrics() {
    return apiClient.get<AdminDetectorMetrics>("/v1/admin/detector/metrics");
  },

  capacity() {
    return apiClient.get<AdminCapacity>("/v1/admin/capacity");
  },
};


export type AdminRuntimeSettingKind = "bool" | "int" | "version" | "enum" | "datetime";

export type AdminRuntimeSetting = {
  key: string;
  kind: AdminRuntimeSettingKind;
  description: string;
  value: unknown;
  default_value: unknown;
  source: "database" | "environment";
  minimum: number | null;
  maximum: number | null;
  choices: string[];
  nullable: boolean;
  updated_by_user_id: string | null;
  updated_at: string | null;
};

export type AdminSystemHealth = {
  status: "ok" | "error";
  detail: string | null;
};

export type AdminSystemStatus = {
  backend_version: string;
  started_at: string;
  components: Record<string, AdminSystemHealth>;
};

export const adminRuntimeSettingsApi = {
  list() {
    return apiClient.get<{ items: AdminRuntimeSetting[] }>("/v1/admin/settings");
  },

  update(key: string, value: unknown, reason: string, stepUpToken: string) {
    return apiClient.request<AdminRuntimeSetting>(
      `/v1/admin/settings/${encodeURIComponent(key)}`,
      {
        method: "PUT",
        json: { value, reason },
        headers: stepUpHeaders(stepUpToken),
      },
    );
  },

  reset(key: string, reason: string, stepUpToken: string) {
    return apiClient.post<AdminRuntimeSetting>(
      `/v1/admin/settings/${encodeURIComponent(key)}/reset`,
      {
        json: { reason },
        headers: stepUpHeaders(stepUpToken),
      },
    );
  },

  systemStatus() {
    return apiClient.get<AdminSystemStatus>("/v1/admin/system/status");
  },
};


export type AdminComplaintEvent = {
  id: string;
  action: string;
  actor_user_id: string | null;
  note: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
};

export type AdminComplaint = {
  id: string;
  kind: "copyright" | "abuse";
  complainant_name: string;
  complainant_email: string;
  channel_source_type: string | null;
  channel_source_value: string | null;
  recording_id: string | null;
  summary: string;
  body: string;
  status: "new" | "reviewing" | "resolved" | "rejected";
  assigned_to_user_id: string | null;
  created_by_user_id: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
  timeline: AdminComplaintEvent[];
};

export type AdminComplaintFilters = {
  cursor?: string | null;
  status?: string;
  kind?: string;
  query?: string;
};

export type AdminCreatorBlock = {
  id: string;
  source_type: string;
  source_value: string;
  complaint_id: string | null;
  reason: string;
  blocked_by_user_id: string | null;
  active: boolean;
  unblocked_at: string | null;
  unblock_reason: string | null;
  created_at: string;
  stopped_recording_ids: string[];
  paused_watch_ids: string[];
};

export type AdminSuspiciousAccount = {
  user_id: string;
  email: string;
  created_at: string;
  rate_limit_hits_24h: number;
  shared_signup_ip_accounts_7d: number;
  reward_valid_7d: number;
  reward_invalid_7d: number;
  reward_invalid_ratio_7d: number;
  reward_invalid_streak: number;
  reward_locked_until: string | null;
  reasons: string[];
};

function complaintQuery(filters: AdminComplaintFilters = {}) {
  const query = new URLSearchParams({ limit: "50" });
  if (filters.cursor) query.set("cursor", filters.cursor);
  if (filters.status) query.set("status", filters.status);
  if (filters.kind) query.set("kind", filters.kind);
  if (filters.query) query.set("query", filters.query);
  return query;
}

export const adminSafetyApi = {
  listComplaints(filters: AdminComplaintFilters = {}) {
    return apiClient.get<{
      items: AdminComplaint[];
      next_cursor: string | null;
      has_more: boolean;
    }>(`/v1/admin/complaints?${complaintQuery(filters).toString()}`);
  },

  exportComplaints(filters: AdminComplaintFilters = {}) {
    const query = complaintQuery(filters);
    query.delete("limit");
    query.delete("cursor");
    return apiClient.get<string>(`/v1/admin/complaints/export.csv?${query.toString()}`, {
      responseMode: "text",
    });
  },

  getComplaint(complaintId: string) {
    return apiClient.get<AdminComplaint>(
      `/v1/admin/complaints/${encodeURIComponent(complaintId)}`,
    );
  },

  createComplaint(payload: {
    kind: "copyright" | "abuse";
    complainant_name: string;
    complainant_email: string;
    channel_source_type?: "username" | "room_id" | "url" | null;
    channel_source_value?: string | null;
    recording_id?: string | null;
    summary: string;
    body: string;
  }) {
    return apiClient.post<AdminComplaint>("/v1/admin/complaints", { json: payload });
  },

  updateComplaint(
    complaintId: string,
    status: AdminComplaint["status"],
    assignedToUserId: string | null,
    reason: string,
  ) {
    return apiClient.patch<AdminComplaint>(
      `/v1/admin/complaints/${encodeURIComponent(complaintId)}`,
      {
        json: {
          status,
          assigned_to_user_id: assignedToUserId,
          reason,
        },
      },
    );
  },

  listCreatorBlocks(activeOnly = true) {
    return apiClient.get<{ items: AdminCreatorBlock[] }>(
      `/v1/admin/creator-blocks?active_only=${activeOnly ? "true" : "false"}`,
    );
  },

  blockCreator(
    payload: {
      source_type: "username" | "room_id" | "url";
      source_value: string;
      complaint_id?: string | null;
      reason: string;
    },
    stepUpToken: string,
  ) {
    return apiClient.post<AdminCreatorBlock>("/v1/admin/creator-blocks", {
      json: payload,
      headers: stepUpHeaders(stepUpToken),
    });
  },

  unblockCreator(blockId: string, reason: string, stepUpToken: string) {
    return apiClient.post<AdminCreatorBlock>(
      `/v1/admin/creator-blocks/${encodeURIComponent(blockId)}/unblock`,
      {
        json: { reason },
        headers: stepUpHeaders(stepUpToken),
      },
    );
  },

  deleteBlockedRecordings(blockId: string, reason: string, stepUpToken: string) {
    return apiClient.post<{
      block_id: string;
      deleted_recording_ids: string[];
      pending_stop_recording_ids: string[];
    }>(
      `/v1/admin/creator-blocks/${encodeURIComponent(blockId)}/delete-recordings`,
      {
        json: { reason },
        headers: stepUpHeaders(stepUpToken),
      },
    );
  },

  suspiciousAccounts(limit = 100) {
    return apiClient.get<{ items: AdminSuspiciousAccount[] }>(
      `/v1/admin/safety/suspicious-accounts?limit=${limit}`,
    );
  },
};


export type AdminDailyMetric = {
  day: string;
  new_users: number;
  active_users_daily: number;
  active_users_weekly: number;
  active_users_monthly: number;
  free_users: number;
  pro_users: number;
  free_to_pro_users: number;
  revenue_web_usd_minor: number;
  revenue_app_store_usd_minor: number;
  revenue_google_play_usd_minor: number;
  recording_running: number;
  recording_waiting: number;
  recording_errors_24h: number;
  recording_capacity_limit: number;
  stuck_orders: number;
  open_complaints: number;
  computed_at: string;
};

export type AdminOverview = {
  latest: AdminDailyMetric | null;
  series: AdminDailyMetric[];
};

export type AdminSupportReport = {
  id: string;
  user_id: string;
  user_email: string;
  recording_id: string | null;
  description: string;
  diagnostic_log: Record<string, unknown>;
  app_version: string | null;
  platform: string | null;
  status: "new" | "reviewing" | "resolved" | "closed";
  assigned_to_user_id: string | null;
  resolved_at: string | null;
  expires_at: string;
  created_at: string;
  updated_at: string;
};

export const adminD9Api = {
  overview(days = 30) {
    return apiClient.get<AdminOverview>(`/v1/admin/overview?days=${days}`);
  },

  listSupportReports(filters: {
    cursor?: string | null;
    status?: string;
    assignedToUserId?: string;
    query?: string;
  } = {}) {
    const query = new URLSearchParams({ limit: "50" });
    if (filters.cursor) query.set("cursor", filters.cursor);
    if (filters.status) query.set("status", filters.status);
    if (filters.assignedToUserId) {
      query.set("assigned_to_user_id", filters.assignedToUserId);
    }
    if (filters.query) query.set("query", filters.query);
    return apiClient.get<{
      items: AdminSupportReport[];
      next_cursor: string | null;
      has_more: boolean;
    }>(`/v1/admin/support-reports?${query.toString()}`);
  },

  getSupportReport(reportId: string) {
    return apiClient.get<AdminSupportReport>(
      `/v1/admin/support-reports/${encodeURIComponent(reportId)}`,
    );
  },

  updateSupportReport(
    reportId: string,
    status: AdminSupportReport["status"],
    assignedToUserId: string | null,
    reason: string,
  ) {
    return apiClient.patch<AdminSupportReport>(
      `/v1/admin/support-reports/${encodeURIComponent(reportId)}`,
      {
        json: {
          status,
          assigned_to_user_id: assignedToUserId,
          reason,
        },
      },
    );
  },
};
