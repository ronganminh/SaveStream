import { apiClient } from "@/api/client";
import { ApiError } from "@/api/errors";
import { parseSseStream } from "@/api/sse";
import type {
  AdminCreditAdjustmentResponse,
  AdminPaymentListResponse,
  AdminRecordingListResponse,
  AdminRefundResponse,
  AdminRetryRecordingResponse,
  AdminUserListResponse,
  AdminUserResponse,
  AuditLogListResponse,
  CheckoutResponse,
  CreateRecordingRequest,
  CreateWatchRequest,
  CreditBalanceResponse,
  CreditPackageListResponse,
  CreditReservationListResponse,
  CreditTransactionListResponse,
  LiveStatusResponse,
  OperationalSnapshotResponse,
  PaymentOrderListResponse,
  PaymentOrderResponse,
  PricingResponse,
  RecordingEventResponse,
  RecordingListResponse,
  RecordingResponse,
  SessionsResponse,
  Source,
  UpdateWatchRequest,
  UserResponse,
  WatchListResponse,
  WatchResponse,
} from "@/api/types";
import type {
  FilteredPageOptions,
  PageOptions,
  SaveStreamRepositories,
} from "@/repositories/contracts";
import { mapWatchToChannel } from "@/repositories/mappers/channel";
import { mapRecordingToModel } from "@/repositories/mappers/recording";

export class UnsupportedBackendCapabilityError extends Error {
  constructor(capability: string) {
    super(`The production backend does not expose an authoritative ${capability} capability yet.`);
    this.name = "UnsupportedBackendCapabilityError";
  }
}

function withQuery(
  path: string,
  values: Record<string, string | number | boolean | null | undefined>,
): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(values)) {
    if (value === undefined || value === null || value === "") continue;
    search.set(key, String(value));
  }
  const query = search.toString();
  return query ? `${path}?${query}` : path;
}

function pageValues(options: PageOptions = {}) {
  return {
    limit: options.limit ?? 100,
    cursor: options.cursor ?? undefined,
  };
}

async function listWatchPage(options: FilteredPageOptions = {}): Promise<WatchListResponse> {
  return apiClient.get<WatchListResponse>(
    withQuery("/v1/watches", {
      ...pageValues(options),
      status: options.status ?? undefined,
    }),
  );
}

async function listRecordingPage(
  options: FilteredPageOptions = {},
): Promise<RecordingListResponse> {
  return apiClient.get<RecordingListResponse>(
    withQuery("/v1/recordings", {
      ...pageValues(options),
      status: options.status ?? undefined,
    }),
  );
}

async function collectAll<T>(
  fetchPage: (cursor: string | null) => Promise<{ items: T[]; pagination: { next_cursor: string | null; has_more: boolean } }>,
): Promise<T[]> {
  const items: T[] = [];
  let cursor: string | null = null;
  for (;;) {
    const page = await fetchPage(cursor);
    items.push(...page.items);
    if (!page.pagination.has_more || !page.pagination.next_cursor) return items;
    cursor = page.pagination.next_cursor;
  }
}

function allWatches() {
  return collectAll<WatchResponse>((cursor) => listWatchPage({ limit: 100, cursor }));
}

function allRecordings() {
  return collectAll<RecordingResponse>((cursor) => listRecordingPage({ limit: 100, cursor }));
}

async function nullable<T>(request: () => Promise<T>): Promise<T | null> {
  try {
    return await request();
  } catch (error) {
    if (error instanceof ApiError && error.status === 404) return null;
    throw error;
  }
}

export const apiRepositories: SaveStreamRepositories = {
  channels: {
    async list() {
      const [watches, recordings] = await Promise.all([allWatches(), allRecordings()]);
      return watches.map((watch) => mapWatchToChannel(watch, recordings));
    },

    async getById(id) {
      const watch = await nullable(() => apiClient.get<WatchResponse>(`/v1/watches/${id}`));
      if (!watch) return null;
      return mapWatchToChannel(watch, await allRecordings());
    },

    listWatches(options) {
      return listWatchPage(options);
    },

    getWatch(id) {
      return apiClient.get<WatchResponse>(`/v1/watches/${id}`);
    },

    create(input: CreateWatchRequest) {
      return apiClient.post<WatchResponse>("/v1/watches", { json: input });
    },

    update(id: string, input: UpdateWatchRequest) {
      return apiClient.patch<WatchResponse>(`/v1/watches/${id}`, { json: input });
    },

    pause(id: string) {
      return apiClient.patch<WatchResponse>(`/v1/watches/${id}`, {
        json: { status: "paused" },
      });
    },

    resume(id: string) {
      return apiClient.post<WatchResponse>(`/v1/watches/${id}/resume`);
    },

    delete(id: string) {
      return apiClient.delete<void>(`/v1/watches/${id}`);
    },
  },

  recordings: {
    async list() {
      const [recordings, watches] = await Promise.all([allRecordings(), allWatches()]);
      return recordings.map((recording) => mapRecordingToModel(recording, watches));
    },

    async getById(id) {
      const recording = await nullable(() =>
        apiClient.get<RecordingResponse>(`/v1/recordings/${id}`),
      );
      if (!recording) return null;
      return mapRecordingToModel(recording, await allWatches());
    },

    async getActive() {
      for (const status of [
        "recording",
        "stop_requested",
        "waiting_live",
        "resolving",
        "queued",
      ] as const) {
        const page = await listRecordingPage({ limit: 1, status });
        if (page.items[0]) {
          return mapRecordingToModel(page.items[0], await allWatches());
        }
      }
      return null;
    },

    async *streamEvents(id, options = {}) {
      const headers = new Headers();
      if (options.lastEventId) headers.set("Last-Event-ID", options.lastEventId);
      const response = await apiClient.get<Response>(`/v1/recordings/${id}/events`, {
        headers,
        signal: options.signal,
        responseMode: "response",
      });

      for await (const message of parseSseStream(response, options.signal)) {
        let parsed: unknown;
        try {
          parsed = JSON.parse(message.data);
        } catch {
          throw new Error("Recording event stream returned invalid JSON.");
        }
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
          throw new Error("Recording event stream returned an invalid event.");
        }
        const event = parsed as Partial<RecordingEventResponse>;
        if (
          typeof event.id !== "string" ||
          typeof event.sequence !== "number" ||
          typeof event.recording_id !== "string" ||
          typeof event.type !== "string" ||
          typeof event.created_at !== "string" ||
          !event.data ||
          typeof event.data !== "object"
        ) {
          throw new Error("Recording event stream returned an invalid event.");
        }
        yield event as RecordingEventResponse;
      }
    },

    listRecordings(options) {
      return listRecordingPage(options);
    },

    getRecording(id: string) {
      return apiClient.get<RecordingResponse>(`/v1/recordings/${id}`);
    },

    getLiveStatus(source: Source) {
      return apiClient.post<LiveStatusResponse>("/v1/live-status", {
        json: { source },
      });
    },

    create(input: CreateRecordingRequest, idempotencyKey: string) {
      return apiClient.post<RecordingResponse>("/v1/recordings", {
        json: input,
        idempotencyKey,
      });
    },

    stop(id: string) {
      return apiClient.post<RecordingResponse>(`/v1/recordings/${id}/stop`);
    },

    delete(id: string) {
      return apiClient.delete<void>(`/v1/recordings/${id}`);
    },
  },

  pricing: {
    get() {
      return apiClient.get<PricingResponse>("/v1/pricing");
    },
  },

  credits: {
    getBalance() {
      return apiClient.get<CreditBalanceResponse>("/v1/credits/balance");
    },

    listTransactions(options = {}) {
      return apiClient.get<CreditTransactionListResponse>(
        withQuery("/v1/credits/transactions", pageValues(options)),
      );
    },

    listReservations(options = {}) {
      return apiClient.get<CreditReservationListResponse>(
        withQuery("/v1/credits/reservations", pageValues(options)),
      );
    },
  },

  billing: {
    listPackages() {
      return apiClient.get<CreditPackageListResponse>("/v1/billing/packages");
    },

    createPaymentOrder(packageId: string, idempotencyKey: string) {
      return apiClient.post<PaymentOrderResponse>("/v1/billing/payment-orders", {
        json: { package_id: packageId },
        idempotencyKey,
      });
    },

    listPaymentOrders(options = {}) {
      return apiClient.get<PaymentOrderListResponse>(
        withQuery("/v1/billing/payment-orders", pageValues(options)),
      );
    },

    getPaymentOrder(id: string) {
      return apiClient.get<PaymentOrderResponse>(`/v1/billing/payment-orders/${id}`);
    },

    createCheckout(id: string, returnUrl: string, idempotencyKey: string) {
      return apiClient.post<CheckoutResponse>(
        `/v1/billing/payment-orders/${id}/checkout`,
        {
          json: { return_url: returnUrl },
          idempotencyKey,
        },
      );
    },
  },

  users: {
    getCurrent() {
      return apiClient.get<UserResponse>("/v1/me");
    },

    updateCurrent(input) {
      return apiClient.patch<UserResponse>("/v1/me", { json: input });
    },

    requestDeletion() {
      return apiClient.delete<{ message: string }>("/v1/me");
    },

    listSessions() {
      return apiClient.get<SessionsResponse>("/v1/me/sessions");
    },

    revokeSession(id: string) {
      return apiClient.delete<void>(`/v1/me/sessions/${id}`);
    },

    exportData() {
      return apiClient.get<unknown>("/v1/me/export");
    },
  },

  admin: {
    listUsers(options = {}) {
      return apiClient.get<AdminUserListResponse>(
        withQuery("/v1/admin/users", {
          ...pageValues(options),
          role: options.role,
          is_active: options.isActive,
        }),
      );
    },

    getUser(id: string) {
      return apiClient.get<AdminUserResponse>(`/v1/admin/users/${id}`);
    },

    updateUser(id, input) {
      return apiClient.patch<AdminUserResponse>(`/v1/admin/users/${id}`, {
        json: input,
      });
    },

    listRecordings(options = {}) {
      return apiClient.get<AdminRecordingListResponse>(
        withQuery("/v1/admin/recordings", {
          ...pageValues(options),
          status: options.status,
          user_id: options.userId,
        }),
      );
    },

    getRecording(id: string) {
      return apiClient.get<RecordingResponse>(`/v1/admin/recordings/${id}`);
    },

    retryRecording(id: string, idempotencyKey: string) {
      return apiClient.post<AdminRetryRecordingResponse>(
        `/v1/admin/recordings/${id}/retry`,
        { idempotencyKey },
      );
    },

    listPayments(options = {}) {
      return apiClient.get<AdminPaymentListResponse>(
        withQuery("/v1/admin/payments", {
          ...pageValues(options),
          status: options.status,
          user_id: options.userId,
        }),
      );
    },

    refundPayment(id, input, idempotencyKey) {
      return apiClient.post<AdminRefundResponse>(
        `/v1/admin/payments/${id}/refunds`,
        {
          json: input,
          idempotencyKey,
        },
      );
    },

    adjustCredits(input, idempotencyKey) {
      return apiClient.post<AdminCreditAdjustmentResponse>(
        "/v1/admin/credits/adjustments",
        {
          json: input,
          idempotencyKey,
        },
      );
    },

    listAudit(options = {}) {
      return apiClient.get<AuditLogListResponse>(
        withQuery("/v1/admin/audit", {
          ...pageValues(options),
          actor_user_id: options.actorUserId,
          resource_type: options.resourceType,
          action: options.action,
        }),
      );
    },

    getOperationalSnapshot() {
      return apiClient.get<OperationalSnapshotResponse>("/v1/admin/operations/snapshot");
    },
  },

  usage: {
    async getCurrent() {
      throw new UnsupportedBackendCapabilityError(
        "legacy Free/Pro quota usage",
      );
    },
  },

  notifications: {
    async list() {
      throw new UnsupportedBackendCapabilityError("persisted notifications");
    },
    async markRead() {
      throw new UnsupportedBackendCapabilityError("persisted notifications");
    },
    async markAllRead() {
      throw new UnsupportedBackendCapabilityError("persisted notifications");
    },
  },
};
