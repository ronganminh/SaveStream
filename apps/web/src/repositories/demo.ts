import {
  activeRecording,
  channels,
  dailyRecordingHours,
  notifications,
  recordings,
  sessions,
  usage,
  user,
  type Notification,
} from "@/mocks/fixtures";
import type {
  ArtifactResponse,
  PaymentOrderResponse,
  RecordingEventResponse,
  RecordingResponse,
  WatchResponse,
} from "@/api/types";
import type {
  ChannelModel,
  RecordingModel,
  SaveStreamRepositories,
} from "@/repositories/contracts";

let notificationState: Notification[] = notifications.map((item) => ({ ...item }));
let notificationPreferenceState = {
  recording_started: true,
  recording_ready: true,
  recording_failed: true,
  email_supported: false as const,
  updated_at: null as string | null,
};

function emptyRecordingEventStream(): AsyncIterable<RecordingEventResponse> {
  return {
    [Symbol.asyncIterator]() {
      return {
        async next(): Promise<IteratorResult<RecordingEventResponse>> {
          return { done: true, value: undefined as never };
        },
      };
    },
  };
}

function demoWatchFromChannel(channel: (typeof channels)[number]): WatchResponse {
  const username = channel.handle.replace(/^@/, "");
  const backendStatus =
    channel.status === "Paused"
      ? "paused"
      : channel.status === "Error"
        ? "paused_error"
        : "active";
  const liveStatus =
    channel.status === "Recording" ? "live" : channel.status === "Offline" ? "offline" : "unknown";
  return {
    id: channel.id,
    source: { type: "username", value: username },
    creator: {
      platform: "tiktok",
      username,
      display_name: channel.name,
      avatar_url: null,
    },
    status: backendStatus,
    live_status: liveStatus,
    auto_record: channel.monitoring,
    last_checked_at: new Date().toISOString(),
    next_check_at: null,
    last_live_at: liveStatus === "live" ? new Date().toISOString() : null,
    created_at: new Date(0).toISOString(),
    updated_at: new Date().toISOString(),
  };
}

function demoChannel(channel: (typeof channels)[number]): ChannelModel {
  const watch = demoWatchFromChannel(channel);
  return {
    ...channel,
    backendStatus: watch.status,
    liveStatus: watch.live_status,
    source: watch.source,
    autoRecord: watch.auto_record,
  };
}

function demoRecordingFromFixture(item: (typeof recordings)[number]): RecordingResponse {
  const channel = channels.find((candidate) => candidate.id === item.channelId);
  const username = item.handle.replace(/^@/, "");
  const status =
    item.status === "Recording"
      ? "recording"
      : item.status === "Ready"
        ? "completed"
        : item.status === "Error"
          ? "failed"
          : "processing";
  const bytes = Math.round(item.sizeGb * 1024 ** 3);
  return {
    id: item.id,
    source: { type: "username", value: username },
    creator: {
      platform: "tiktok",
      username,
      display_name: channel?.name ?? username,
      avatar_url: null,
    },
    status,
    started_at: new Date(`${item.date} ${item.time}`).toISOString(),
    ended_at: status === "recording" ? null : new Date(`${item.date} ${item.time}`).toISOString(),
    duration_seconds: 0,
    bytes_recorded: bytes,
    estimated_max_cost: 0,
    actual_cost: status === "recording" ? null : 0,
    credit_reservation_id: null,
    actions: {
      can_stop: status === "recording",
      can_retry: status === "failed",
      can_delete: status === "completed" || status === "failed",
    },
    error: item.error
      ? { code: "DEMO_RECORDING_ERROR", message: item.error, retryable: true }
      : null,
    created_at: new Date(`${item.date} ${item.time}`).toISOString(),
    updated_at: new Date(`${item.date} ${item.time}`).toISOString(),
  };
}

function demoRecording(item: (typeof recordings)[number]): RecordingModel {
  const raw = demoRecordingFromFixture(item);
  return {
    ...item,
    backendStatus: raw.status,
    source: raw.source,
    actions: raw.actions,
  };
}

const demoWatchState = channels.map(demoWatchFromChannel);
const demoChannelState = channels.map(demoChannel);
const demoRecordingState = recordings.map(demoRecordingFromFixture);
const deletedDemoRecordingIds = new Set<string>();

function channelStatusFromWatch(watch: WatchResponse): ChannelModel["status"] {
  if (watch.status === "paused_error") return "Error";
  if (
    watch.status === "paused" ||
    watch.status === "paused_insufficient_credit" ||
    watch.status === "disabled"
  ) {
    return "Paused";
  }
  if (watch.live_status === "live") return "Recording";
  if (watch.live_status === "offline") return "Offline";
  return "Waiting";
}

function syncDemoChannel(watch: WatchResponse) {
  const existing = demoChannelState.find((channel) => channel.id === watch.id);
  if (existing) {
    existing.status = channelStatusFromWatch(watch);
    existing.monitoring = watch.status === "active";
    existing.backendStatus = watch.status;
    existing.liveStatus = watch.live_status;
    existing.source = structuredClone(watch.source);
    existing.autoRecord = watch.auto_record;
    existing.checked = watch.last_checked_at ? "Now" : "—";
    existing.live = watch.live_status === "live" ? "Live now" : existing.live;
    return;
  }

  const username =
    watch.creator?.username ??
    (watch.source.type === "username" ? watch.source.value.replace(/^@/, "") : watch.source.value);
  const name = watch.creator?.display_name || username;
  demoChannelState.push({
    id: watch.id,
    name,
    handle: username ? `@${username.replace(/^@/, "")}` : watch.source.value,
    initials:
      name
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0]?.toUpperCase() ?? "")
        .join("") || "SS",
    platform: "tiktok",
    status: channelStatusFromWatch(watch),
    monitoring: watch.status === "active",
    live: watch.live_status === "live" ? "Live now" : "—",
    checked: watch.last_checked_at ? "Now" : "—",
    recordings: 0,
    recordedHours: "0 h",
    storage: "0 GB",
    tone: "from-avatar-one to-avatar-one-end",
    backendStatus: watch.status,
    liveStatus: watch.live_status,
    source: structuredClone(watch.source),
    autoRecord: watch.auto_record,
  });
}

function demoPaymentOrder(packageId: string): PaymentOrderResponse {
  const now = new Date().toISOString();
  return {
    id: "demo-order",
    package_id: packageId,
    status: "created",
    credits: 100,
    amount: { amount_minor: 999, currency: "USD" },
    provider: "demo",
    provider_reference: null,
    created_at: now,
    updated_at: now,
  };
}

export const demoRepositories: SaveStreamRepositories = {
  channels: {
    async list() {
      return demoChannelState.map((item) => structuredClone(item));
    },
    async getById(id) {
      const item = demoChannelState.find((channel) => channel.id === id);
      return item ? structuredClone(item) : null;
    },
    async listWatches() {
      return {
        items: demoWatchState.map((item) => structuredClone(item)),
        pagination: { next_cursor: null, has_more: false },
      };
    },
    async getWatch(id) {
      const item = demoWatchState.find((watch) => watch.id === id);
      if (!item) throw new Error("Demo watch not found");
      return structuredClone(item);
    },
    async create(input) {
      const now = new Date().toISOString();
      const item: WatchResponse = {
        id: `demo-watch-${demoWatchState.length + 1}`,
        source: structuredClone(input.source),
        creator: null,
        status: "active",
        live_status: "unknown",
        auto_record: input.auto_record,
        last_checked_at: null,
        next_check_at: null,
        last_live_at: null,
        created_at: now,
        updated_at: now,
      };
      demoWatchState.push(item);
      syncDemoChannel(item);
      return structuredClone(item);
    },
    async update(id, input) {
      const item = demoWatchState.find((watch) => watch.id === id);
      if (!item) throw new Error("Demo watch not found");
      if (input.auto_record !== undefined && input.auto_record !== null) item.auto_record = input.auto_record;
      if (input.status) item.status = input.status;
      item.updated_at = new Date().toISOString();
      syncDemoChannel(item);
      return structuredClone(item);
    },
    async pause(id) {
      const item = demoWatchState.find((watch) => watch.id === id);
      if (!item) throw new Error("Demo watch not found");
      item.status = "paused";
      item.updated_at = new Date().toISOString();
      syncDemoChannel(item);
      return structuredClone(item);
    },
    async resume(id) {
      const item = demoWatchState.find((watch) => watch.id === id);
      if (!item) throw new Error("Demo watch not found");
      item.status = "active";
      item.updated_at = new Date().toISOString();
      syncDemoChannel(item);
      return structuredClone(item);
    },
    async delete(id) {
      const watchIndex = demoWatchState.findIndex((watch) => watch.id === id);
      if (watchIndex >= 0) demoWatchState.splice(watchIndex, 1);
      const channelIndex = demoChannelState.findIndex((channel) => channel.id === id);
      if (channelIndex >= 0) demoChannelState.splice(channelIndex, 1);
    },
  },

  recordings: {
    async list() {
      return recordings
        .filter((recording) => !deletedDemoRecordingIds.has(recording.id))
        .map(demoRecording);
    },
    async getById(id) {
      if (deletedDemoRecordingIds.has(id)) return null;
      const item = recordings.find((recording) => recording.id === id);
      return item ? demoRecording(item) : null;
    },
    async getActive() {
      if (!activeRecording || deletedDemoRecordingIds.has(activeRecording.id)) return null;
      return {
        ...activeRecording,
        backendStatus: "recording",
        source: { type: "username", value: activeRecording.handle.replace(/^@/, "") },
        actions: { can_stop: true, can_retry: false, can_delete: false },
      };
    },
    streamEvents() {
      return emptyRecordingEventStream();
    },
    async listRecordings() {
      return {
        items: demoRecordingState.map((item) => structuredClone(item)),
        pagination: { next_cursor: null, has_more: false },
      };
    },
    async getRecording(id) {
      if (deletedDemoRecordingIds.has(id)) throw new Error("Demo recording not found");
      const item = demoRecordingState.find((recording) => recording.id === id);
      if (!item) throw new Error("Demo recording not found");
      return structuredClone(item);
    },
    async listArtifacts(id) {
      if (deletedDemoRecordingIds.has(id)) return [];
      const recording = demoRecordingState.find((item) => item.id === id);
      if (!recording || recording.status === "recording") return [];
      const artifact: ArtifactResponse = {
        id: `demo-artifact-${id}`,
        recording_id: id,
        kind: "video",
        container: "mp4",
        size_bytes: recording.bytes_recorded,
        checksum_sha256: "demo".padEnd(64, "0"),
        created_at: recording.updated_at,
      };
      return [artifact];
    },
    async createArtifactDownloadUrl(artifactId) {
      return {
        url: `https://demo.savestream.invalid/artifacts/${artifactId}.mp4`,
        expires_at: new Date(Date.now() + 60_000).toISOString(),
      };
    },
    async getLiveStatus(source) {
      return {
        source: structuredClone(source),
        creator: null,
        live_status: "unknown",
        room_id: null,
        checked_at: new Date().toISOString(),
      };
    },
    async create(input) {
      const now = new Date().toISOString();
      const item: RecordingResponse = {
        id: `demo-recording-${demoRecordingState.length + 1}`,
        source: structuredClone(input.source),
        creator: null,
        status: "queued",
        started_at: null,
        ended_at: null,
        duration_seconds: 0,
        bytes_recorded: 0,
        estimated_max_cost: 0,
        actual_cost: null,
        credit_reservation_id: null,
        actions: { can_stop: true, can_retry: false, can_delete: false },
        error: null,
        created_at: now,
        updated_at: now,
      };
      demoRecordingState.push(item);
      return structuredClone(item);
    },
    async stop(id) {
      const item = demoRecordingState.find((recording) => recording.id === id);
      if (!item) throw new Error("Demo recording not found");
      item.status = "stop_requested";
      item.updated_at = new Date().toISOString();
      return structuredClone(item);
    },
    async delete(id) {
      deletedDemoRecordingIds.add(id);
      const index = demoRecordingState.findIndex((recording) => recording.id === id);
      if (index >= 0) demoRecordingState.splice(index, 1);
    },
  },

  pricing: {
    async get() {
      return { version: "demo", credit_unit: "credit", rules: [] };
    },
    async getPublic() {
      return {
        packages: [
          {
            id: "demo-100",
            code: "demo",
            name: "100 credits",
            credits: 100,
            price: { amount_minor: 999, currency: "USD" },
            recording_minutes: 100,
          },
        ],
        recording_rate: { unit_seconds: 60, credits_per_unit: 1, minimum_credits: 1 },
        signup_credits: 10,
        max_channels_per_user: 20,
        max_concurrent_recordings_per_user: 2,
      };
    },
  },

  credits: {
    async getBalance() {
      return { posted: 500, reserved: 50, available: 450 };
    },
    async listTransactions() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
    async listReservations() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
  },

  billing: {
    async listPackages() {
      return {
        items: [
          {
            id: "demo-100",
            name: "100 credits",
            credits: 100,
            price: { amount_minor: 999, currency: "USD" },
            active: true,
          },
        ],
      };
    },
    async createPaymentOrder(packageId) {
      return demoPaymentOrder(packageId);
    },
    async listPaymentOrders() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
    async getPaymentOrder(id) {
      const order = { ...demoPaymentOrder("demo-100"), id };
      if (id === "demo-paid") order.status = "paid";
      if (id === "demo-cancelled") order.status = "cancelled";
      return order;
    },
    async createCheckout(id) {
      return {
        checkout_url: "https://demo.savestream.invalid/checkout",
        payment_order: { ...demoPaymentOrder("demo-100"), id },
      };
    },
  },

  users: {
    async getCurrent() {
      return {
        id: user.id,
        role: "admin",
        email: user.email,
        email_verified: user.emailVerified,
        display_name: user.name,
        locale: "en",
        created_at: new Date(0).toISOString(),
      };
    },
    async updateCurrent(input) {
      return {
        id: user.id,
        role: "admin",
        email: user.email,
        email_verified: user.emailVerified,
        display_name: input.display_name === undefined ? user.name : input.display_name,
        locale: input.locale ?? "en",
        created_at: new Date(0).toISOString(),
      };
    },
    async requestDeletion() {
      return { message: "Demo account deletion requested" };
    },
    async listSessions() {
      return {
        items: sessions.map((session) => ({
          id: session.id,
          created_at: new Date(0).toISOString(),
          last_seen_at: new Date().toISOString(),
          current: session.current,
          user_agent: session.device,
          ip_hint: session.location,
        })),
      };
    },
    async revokeSession() {},
    async exportData() {
      return { demo: true, user };
    },
  },

  admin: {
    async listUsers() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
    async getUser(id) {
      const now = new Date().toISOString();
      return {
        id,
        email: user.email,
        display_name: user.name,
        role: "admin",
        is_active: true,
        email_verified_at: now,
        deletion_requested_at: null,
        created_at: now,
        updated_at: now,
      };
    },
    async updateUser(id, input) {
      const current = await this.getUser(id);
      return {
        ...current,
        ...(input.role ? { role: input.role } : {}),
        ...(input.is_active !== undefined ? { is_active: input.is_active } : {}),
      };
    },
    async listRecordings() {
      return {
        items: demoRecordingState.map((item) => structuredClone(item)),
        pagination: { next_cursor: null, has_more: false },
      };
    },
    async getRecording(id) {
      const item = demoRecordingState.find((recording) => recording.id === id);
      if (!item) throw new Error("Demo recording not found");
      return structuredClone(item);
    },
    async retryRecording(id) {
      const original = await this.getRecording(id);
      const retry = {
        ...original,
        id: `${id}-retry`,
        status: "queued" as const,
        error: null,
      };
      return { original_recording_id: id, recording: retry };
    },
    async listPayments() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
    async refundPayment(id, input) {
      return {
        id: "demo-refund",
        payment_order_id: id,
        status: "pending",
        credits: input.credits,
        amount_minor: input.amount_minor,
        provider: "demo",
        provider_refund_reference: null,
        created_at: new Date().toISOString(),
      };
    },
    async adjustCredits(input) {
      return {
        transaction: {
          id: "demo-adjustment",
          type: "adjustment",
          amount: input.amount,
          balance_after: 500 + input.amount,
          reference_type: "admin_adjustment",
          reference_id: input.user_id,
          created_at: new Date().toISOString(),
        },
      };
    },
    async listAudit() {
      return { items: [], pagination: { next_cursor: null, has_more: false } };
    },
    async getOperationalSnapshot() {
      return {
        active_recordings: 1,
        failed_recordings_recent: 0,
        pending_outbox_events: 0,
        unprocessed_payment_events: 0,
        pending_payment_orders: 0,
        paused_error_watches: 0,
      };
    },
  },

  usage: {
    async getCurrent() {
      return {
        summary: structuredClone(usage),
        dailyRecordingHours: [...dailyRecordingHours],
      };
    },
  },

  notifications: {
    async list() {
      return notificationState.map((item) => ({ ...item }));
    },
    async markRead(id) {
      notificationState = notificationState.map((item) =>
        item.id === id ? { ...item, read: true } : item,
      );
    },
    async markAllRead() {
      notificationState = notificationState.map((item) => ({ ...item, read: true }));
    },
    async getPreferences() {
      return { ...notificationPreferenceState };
    },
    async updatePreferences(input) {
      notificationPreferenceState = {
        ...notificationPreferenceState,
        ...input,
        updated_at: new Date().toISOString(),
      };
      return { ...notificationPreferenceState };
    },
  },
};
