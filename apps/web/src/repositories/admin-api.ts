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
  cursor?: string | null;
  query?: string;
  plan?: "free" | "pro" | "";
  accountStatus?: "active" | "locked" | "pending_deletion" | "deleted" | "";
  emailVerified?: "true" | "false" | "";
  createdFrom?: string;
  createdTo?: string;
  purchaseProvider?: string;
  sortBy?: "created_at" | "email";
  sortOrder?: "asc" | "desc";
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
    if (filters.createdFrom) query.set("created_from", filters.createdFrom);
    if (filters.createdTo) query.set("created_to", filters.createdTo);
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
    if (filters.createdFrom) query.set("created_from", filters.createdFrom);
    if (filters.createdTo) query.set("created_to", filters.createdTo);
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
