import { apiBaseUrl } from "@/lib/app-config";
import {
  ApiError,
  REQUEST_ID_HEADER,
  apiErrorFromResponse,
  apiNetworkError,
} from "@/api/errors";

export type ApiResponseMode = "json" | "text" | "response";

export type ApiRequestOptions = Omit<RequestInit, "body" | "headers"> & {
  headers?: HeadersInit;
  body?: BodyInit | null;
  json?: unknown;
  accessToken?: string | null;
  idempotencyKey?: string | null;
  requestId?: string;
  responseMode?: ApiResponseMode;
  skipAuth?: boolean;
  skipAuthRefresh?: boolean;
};

type ApiSessionHooks = {
  getAccessToken: () => string | null;
  refreshAccessToken: () => Promise<string | null>;
  onAuthExpired: () => void;
};

let apiSessionHooks: ApiSessionHooks | null = null;

export function configureApiSession(hooks: ApiSessionHooks | null) {
  apiSessionHooks = hooks;
}

function createRequestId(): string {
  if (typeof globalThis.crypto?.randomUUID === "function") {
    return globalThis.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

function buildApiUrl(baseUrl: string, path: string): string {
  if (!baseUrl) {
    throw new Error("SaveStream API is not configured. Set VITE_API_BASE_URL.");
  }
  if (/^[A-Za-z][A-Za-z\d+.-]*:/.test(path)) {
    throw new Error("API request paths must be relative to VITE_API_BASE_URL.");
  }

  const relativePath = path.startsWith("/") ? path.slice(1) : path;
  return new URL(relativePath, `${baseUrl}/`).toString();
}

export class ApiClient {
  constructor(private readonly baseUrl: string) {}

  async request<T>(path: string, options: ApiRequestOptions = {}): Promise<T> {
    const {
      headers: initialHeaders,
      body,
      json,
      accessToken: requestedAccessToken,
      idempotencyKey,
      requestId: requestedRequestId,
      responseMode = "json",
      credentials = "include",
      skipAuth = false,
      skipAuthRefresh = false,
      ...requestInit
    } = options;

    if (json !== undefined && body !== undefined && body !== null) {
      throw new Error("Provide either json or body for an API request, not both.");
    }

    const headers = new Headers(initialHeaders);
    const requestId = requestedRequestId ?? headers.get(REQUEST_ID_HEADER) ?? createRequestId();
    headers.set(REQUEST_ID_HEADER, requestId);

    const accessToken =
      requestedAccessToken ?? (!skipAuth ? apiSessionHooks?.getAccessToken() : null);
    if (accessToken) headers.set("Authorization", `Bearer ${accessToken}`);
    if (idempotencyKey) headers.set("Idempotency-Key", idempotencyKey);

    let requestBody = body;
    if (json !== undefined) {
      headers.set("Content-Type", headers.get("Content-Type") ?? "application/json");
      requestBody = JSON.stringify(json);
    }

    const url = buildApiUrl(this.baseUrl, path);
    let response: Response;
    try {
      response = await fetch(url, {
        ...requestInit,
        credentials,
        headers,
        ...(requestBody !== undefined ? { body: requestBody } : {}),
      });
    } catch (error) {
      if (requestInit.signal?.aborted) throw error;
      if (error instanceof ApiError) throw error;
      throw apiNetworkError(error, requestId);
    }

    if (
      response.status === 401 &&
      !skipAuth &&
      !skipAuthRefresh &&
      apiSessionHooks
    ) {
      let refreshedAccessToken: string | null = null;
      try {
        refreshedAccessToken = await apiSessionHooks.refreshAccessToken();
      } catch {
        refreshedAccessToken = null;
      }

      if (refreshedAccessToken) {
        return this.request<T>(path, {
          ...options,
          accessToken: refreshedAccessToken,
          requestId,
          skipAuthRefresh: true,
        });
      }
      apiSessionHooks.onAuthExpired();
    }

    if (!response.ok) {
      throw await apiErrorFromResponse(response, requestId);
    }

    if (responseMode === "response") return response as T;
    if (response.status === 204 || response.status === 205) return undefined as T;
    if (responseMode === "text") return (await response.text()) as T;

    const text = await response.text();
    if (!text) return undefined as T;

    try {
      return JSON.parse(text) as T;
    } catch (error) {
      throw new ApiError({
        status: response.status,
        code: "INVALID_RESPONSE",
        requestId: response.headers.get(REQUEST_ID_HEADER) ?? requestId,
        retryable: false,
        cause: error,
      });
    }
  }

  get<T>(path: string, options: ApiRequestOptions = {}) {
    return this.request<T>(path, { ...options, method: "GET" });
  }

  post<T>(path: string, options: ApiRequestOptions = {}) {
    return this.request<T>(path, { ...options, method: "POST" });
  }

  patch<T>(path: string, options: ApiRequestOptions = {}) {
    return this.request<T>(path, { ...options, method: "PATCH" });
  }

  delete<T>(path: string, options: ApiRequestOptions = {}) {
    return this.request<T>(path, { ...options, method: "DELETE" });
  }
}

export const apiClient = new ApiClient(apiBaseUrl);
