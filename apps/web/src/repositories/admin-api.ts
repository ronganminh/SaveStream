import { apiClient } from "@/api/client";

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
};

type Pagination = {
  next_cursor: string | null;
  has_more: boolean;
};

export type AdminListResponse = {
  items: AdminUser[];
  pagination: Pagination;
};

function stepUpHeaders(token: string): HeadersInit {
  return { "X-Admin-Step-Up": token };
}

export const adminFoundationApi = {
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
