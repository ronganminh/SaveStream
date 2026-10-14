import type { LegalConsent } from "@/lib/legal";
import { ApiError } from "@/api/errors";
import { apiClient } from "@/api/client";

export type AuthRole = "user" | "owner" | "support" | "finance" | "admin";

export type AuthUser = {
  id: string;
  role: AuthRole;
  email: string;
  email_verified: boolean;
  display_name: string | null;
  locale: string;
  created_at: string;
  admin_mfa_enabled: boolean;
  admin_mfa_verified: boolean;
};

type AuthMessage = {
  message: string;
};

type TokenResponse = {
  access_token: string;
  token_type: "Bearer";
  expires_in: number;
  refresh_token: string | null;
};

export const authApi = {
  register(input: {
    email: string;
    password: string;
    display_name?: string | null;
    consent: LegalConsent;
  }) {
    return apiClient.post<AuthMessage>("/v1/auth/register", {
      json: { ...input, client_type: "web" },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  verifyEmail(token: string) {
    return apiClient.post<AuthMessage>("/v1/auth/verify-email", {
      json: { token },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  resendVerification(email: string) {
    return apiClient.post<AuthMessage>("/v1/auth/resend-verification", {
      json: { email },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  login(email: string, password: string) {
    return apiClient.post<TokenResponse>("/v1/auth/login", {
      json: { email, password, client_type: "web" },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  socialLogin(idToken: string, consent?: LegalConsent) {
    return apiClient.post<TokenResponse>("/v1/auth/social", {
      json: { id_token: idToken, client_type: "web", ...(consent ? { consent } : {}) },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  linkSocial(idToken: string, password: string) {
    return apiClient.post<AuthMessage>("/v1/auth/social/link", {
      json: { id_token: idToken, password },
    });
  },

  refresh() {
    return apiClient.post<TokenResponse>("/v1/auth/refresh", {
      json: {},
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  logout() {
    return apiClient.post<void>("/v1/auth/logout");
  },

  logoutAll() {
    return apiClient.post<void>("/v1/auth/logout-all");
  },

  forgotPassword(email: string) {
    return apiClient.post<AuthMessage>("/v1/auth/forgot-password", {
      json: { email },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  resetPassword(token: string, password: string) {
    return apiClient.post<AuthMessage>("/v1/auth/reset-password", {
      json: { token, password },
      skipAuth: true,
      skipAuthRefresh: true,
    });
  },

  getCurrentUser(accessToken?: string) {
    return apiClient.get<AuthUser>("/v1/me", {
      ...(accessToken ? { accessToken } : {}),
    });
  },
};

export function authErrorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) return "Something went wrong. Please try again.";
  if (error.status === 0) return "Unable to reach SaveStream. Check your connection and try again.";

  switch (error.code) {
    case "AUTH_INVALID_CREDENTIALS":
      return "Email or password is incorrect.";
    case "AUTH_EMAIL_NOT_VERIFIED":
      return "Verify your email address before signing in.";
    case "AUTH_ACCOUNT_LINK_REQUIRED":
      return "An account with this email already exists. Sign in below with your password to link Google or Apple.";
    case "AUTH_SOCIAL_INVALID_TOKEN":
      return "Your Google or Apple sign-in expired. Please try again.";
    case "AUTH_SOCIAL_EMAIL_REQUIRED":
      return "Your provider must share a verified email for first sign-in.";
    case "SOCIAL_AUTH_NOT_CONFIGURED":
      return "Google and Apple sign-in are not enabled yet.";
    case "LEGAL_CONSENT_REQUIRED":
      return "Confirm that you are at least 18 and agree to the Terms of Use and Privacy Policy.";
    case "LEGAL_VERSION_OUTDATED":
      return "Our Terms of Use or Privacy Policy changed. Reload the page and review them again.";
    case "AUTH_SOCIAL_ALREADY_LINKED":
      return "This Google or Apple account is already linked to another account.";
    case "AUTH_SESSION_REVOKED":
      return "Your session has expired. Sign in again.";
    case "ADMIN_MFA_SETUP_REQUIRED":
      return "Set up two-factor authentication to continue.";
    case "ADMIN_MFA_REQUIRED":
      return "Verify your two-factor authentication code to continue.";
    case "AUTH_INVALID_MFA":
      return "The authentication code is invalid.";
    case "ADMIN_STEP_UP_REQUIRED":
      return "Confirm your password and authentication code to continue.";
    case "RATE_LIMITED":
      return "Too many attempts. Please wait a moment and try again.";
    case "VALIDATION_ERROR":
      return "Check the information you entered and try again.";
    case "RESOURCE_NOT_FOUND":
      return error.serverMessage ?? "The requested item was not found.";
    case "FORBIDDEN":
      return "You do not have permission to perform this action.";
    default:
      return error.status >= 500
        ? "SaveStream is temporarily unavailable. Please try again."
        : "The request could not be completed. Please try again.";
  }
}
