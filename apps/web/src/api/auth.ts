import { ApiError } from "@/api/errors";
import { apiClient } from "@/api/client";

export type AuthRole = "user" | "admin";

export type AuthUser = {
  id: string;
  role: AuthRole;
  email: string;
  email_verified: boolean;
  display_name: string | null;
  locale: string;
  created_at: string;
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
  register(input: { email: string; password: string; display_name?: string | null }) {
    return apiClient.post<AuthMessage>("/v1/auth/register", {
      json: input,
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
    case "AUTH_SESSION_REVOKED":
      return "Your session has expired. Sign in again.";
    case "RATE_LIMITED":
      return "Too many attempts. Please wait a moment and try again.";
    case "VALIDATION_ERROR":
      return "Check the information you entered and try again.";
    case "FORBIDDEN":
      return "You do not have permission to perform this action.";
    default:
      return error.status >= 500
        ? "SaveStream is temporarily unavailable. Please try again."
        : "The request could not be completed. Please try again.";
  }
}
