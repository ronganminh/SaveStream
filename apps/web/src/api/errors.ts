export const REQUEST_ID_HEADER = "X-Request-ID";

export type BackendErrorEnvelope = {
  error?: {
    code?: unknown;
    message?: unknown;
    request_id?: unknown;
    retryable?: unknown;
    details?: unknown;
  };
};

type ApiErrorOptions = {
  status: number;
  code?: string;
  serverMessage?: string;
  details?: unknown;
  requestId?: string;
  retryable?: boolean;
  cause?: unknown;
};

export class ApiError extends Error {
  readonly status: number;
  readonly code: string | undefined;
  readonly serverMessage: string | undefined;
  readonly details: unknown;
  readonly requestId: string | undefined;
  readonly retryable: boolean;

  constructor({
    status,
    code,
    serverMessage,
    details,
    requestId,
    retryable = false,
    cause,
  }: ApiErrorOptions) {
    const statusLabel = status === 0 ? "network error" : `HTTP ${status}`;
    super(`SaveStream API request failed (${statusLabel}${code ? `, ${code}` : ""}).`, {
      cause,
    });
    this.name = "ApiError";
    this.status = status;
    this.code = code;
    this.serverMessage = serverMessage;
    this.details = details;
    this.requestId = requestId;
    this.retryable = retryable;
  }
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  return value as Record<string, unknown>;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

export async function apiErrorFromResponse(
  response: Response,
  fallbackRequestId?: string,
): Promise<ApiError> {
  let payload: unknown;
  try {
    payload = await response.clone().json();
  } catch {
    payload = undefined;
  }

  const root = asRecord(payload) as BackendErrorEnvelope | undefined;
  const error = asRecord(root?.error);
  const code = asString(error?.["code"]);
  const serverMessage = asString(error?.["message"]);
  const requestId =
    asString(error?.["request_id"]) ??
    response.headers.get(REQUEST_ID_HEADER) ??
    fallbackRequestId;

  return new ApiError({
    status: response.status,
    ...(code ? { code } : {}),
    ...(serverMessage ? { serverMessage } : {}),
    ...(error && "details" in error ? { details: error["details"] } : {}),
    ...(requestId ? { requestId } : {}),
    retryable:
      typeof error?.["retryable"] === "boolean"
        ? error["retryable"]
        : response.status === 429 || response.status >= 500,
  });
}

export function apiNetworkError(cause: unknown, requestId: string): ApiError {
  return new ApiError({
    status: 0,
    code: "NETWORK_ERROR",
    requestId,
    retryable: true,
    cause,
  });
}
