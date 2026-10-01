import {
  channels as legacyChannels,
  recordings as legacyRecordings,
  usage as legacyUsage,
  type Channel as LegacyChannel,
  type Recording as LegacyRecording,
} from "@/mocks/fixtures";
import type {
  Channel,
  ChannelStatus,
  Recording,
  RecordingStatus,
  UsageSummary,
} from "@/domain/models";
import { createSupportReference } from "@/domain/models";
import type {
  ChannelLookupResult,
  DownloadResult,
  MutationResult,
  SaveStreamRepository,
} from "@/data/repository";

const channelStatusMap: Record<LegacyChannel["status"], ChannelStatus> = {
  Recording: "recording",
  Waiting: "waiting",
  Offline: "offline",
  Paused: "paused",
  Error: "error",
};

const recordingStatusMap: Record<LegacyRecording["status"], RecordingStatus> = {
  Recording: "recording",
  Processing: "processing",
  Ready: "ready",
  Error: "failed",
};

export const adaptChannel = (channel: LegacyChannel): Channel => ({
  ...channel,
  status: channelStatusMap[channel.status],
});

export const adaptRecording = (recording: LegacyRecording): Recording => ({
  ...recording,
  status: recordingStatusMap[recording.status],
});

export const mockChannels = legacyChannels.map(adaptChannel);
export const mockRecordings = legacyRecordings.map(adaptRecording);

const channelSeed = mockChannels[0]!;
export const channelStatusFixtures: Record<ChannelStatus, Channel> = {
  offline: { ...channelSeed, id: "fixture-offline", status: "offline", live: "Offline" },
  checking: { ...channelSeed, id: "fixture-checking", status: "checking", checked: "Checking now" },
  waiting: { ...channelSeed, id: "fixture-waiting", status: "waiting", live: "Waiting for live" },
  live: { ...channelSeed, id: "fixture-live", status: "live", live: "Live now" },
  recording: { ...channelSeed, id: "fixture-recording", status: "recording", live: "Live now · 01:42:18" },
  paused: { ...channelSeed, id: "fixture-paused", status: "paused", monitoring: false, live: "Paused" },
  error: { ...channelSeed, id: "fixture-error", status: "error", checked: "Check failed" },
};

const readySeed = mockRecordings.find((recording) => recording.status === "ready") ?? mockRecordings[0]!;
const failedSeed = mockRecordings.find((recording) => recording.status === "failed") ?? readySeed;
export const recordingStatusFixtures: Record<RecordingStatus, Recording> = {
  queued: { ...readySeed, id: "fixture-queued", status: "queued", duration: "—", size: "—", sizeGb: 0, expires: "—", expiresDays: null },
  recording: { ...readySeed, id: "fixture-recording", status: "recording", title: "Live now", expires: "—", expiresDays: null },
  processing: { ...readySeed, id: "fixture-processing", status: "processing", expires: "—", expiresDays: null },
  ready: { ...readySeed, id: "fixture-ready", status: "ready" },
  partial: { ...failedSeed, id: "fixture-partial", status: "partial", error: "Stream disconnected", partialDuration: "47 minutes" },
  failed: { ...failedSeed, id: "fixture-failed", status: "failed" },
  expired: { ...readySeed, id: "fixture-expired", status: "expired", expires: "Expired", expiresDays: 0 },
  deleting: { ...readySeed, id: "fixture-deleting", status: "deleting" },
};

export const mockUsage: UsageSummary = { ...legacyUsage, quotaState: "normal" };

export const quotaStateFixtures: Record<UsageSummary["quotaState"], UsageSummary> = {
  normal: mockUsage,
  warning: {
    ...legacyUsage,
    recordingHours: { ...legacyUsage.recordingHours, used: legacyUsage.recordingHours.limit * 0.82 },
    quotaState: "warning",
  },
  exhausted: {
    ...legacyUsage,
    recordingHours: { ...legacyUsage.recordingHours, used: legacyUsage.recordingHours.limit },
    quotaState: "exhausted",
  },
  resetting: { ...legacyUsage, quotaState: "resetting" },
  unavailable: { ...legacyUsage, quotaState: "unavailable" },
};

const wait = (ms = 180) => new Promise((resolve) => setTimeout(resolve, ms));

function normalizeHandle(input: string) {
  const trimmed = input.trim();
  const fromUrl = trimmed.match(/tiktok\.com\/@([A-Za-z0-9._]{2,24})/i)?.[1];
  const raw = (fromUrl ?? trimmed.replace(/^@/, "")).toLowerCase();
  return /^[a-z0-9._]{2,24}$/.test(raw) ? `@${raw}` : null;
}

export class MockSaveStreamRepository implements SaveStreamRepository {
  async listChannels() {
    await wait();
    return mockChannels.map((channel) => ({ ...channel }));
  }

  async getChannel(id: string) {
    await wait();
    return mockChannels.find((channel) => channel.id === id) ?? null;
  }

  async listRecordings() {
    await wait();
    return mockRecordings.map((recording) => ({ ...recording }));
  }

  async getRecording(id: string) {
    await wait();
    if (id === "lina-live") return recordingStatusFixtures.recording;
    return mockRecordings.find((recording) => recording.id === id) ?? null;
  }

  async getUsage() {
    await wait();
    return quotaStateFixtures.normal;
  }

  async lookupChannel(input: string): Promise<ChannelLookupResult> {
    await wait(350);
    if (!input.trim()) return { state: "empty" };
    const handle = normalizeHandle(input);
    if (!handle) return { state: "invalid" };
    const existing = mockChannels.find((channel) => channel.handle.toLowerCase() === handle);
    if (existing) return { state: "already_added" };
    if (handle.includes("notfound")) return { state: "not_found" };
    if (handle.includes("limit")) return { state: "limit_reached" };
    if (handle.includes("unavailable")) return { state: "not_found" };
    const name = handle
      .slice(1)
      .replace(/[._]/g, " ")
      .replace(/\b\w/g, (character) => character.toUpperCase());
    return {
      state: "found",
      channel: {
        name,
        handle,
        initials: name
          .split(" ")
          .map((word) => word[0])
          .join("")
          .slice(0, 2),
        platform: "tiktok",
      },
    };
  }

  async addChannel(handle: string, authorized: boolean): Promise<MutationResult<Channel>> {
    await wait(500);
    if (!authorized) {
      return {
        ok: false,
        error: {
          title: "Authorization required",
          body: "Confirm that you own, manage, or have permission to record this channel.",
          referenceId: createSupportReference("ADD"),
          retryable: false,
        },
      };
    }
    if (handle.includes("adderror")) {
      return {
        ok: false,
        error: {
          title: "Channel couldn’t be added",
          body: "The demo mutation failed before anything changed.",
          referenceId: createSupportReference("ADD"),
          retryable: true,
        },
      };
    }
    const template = channelSeed;
    return {
      ok: true,
      data: {
        ...template,
        id: `mock-${handle.replace(/^@/, "")}`,
        handle,
        name: handle.slice(1),
        initials: handle.slice(1, 3).toUpperCase(),
        status: "waiting",
        live: "Waiting for live",
        checked: "Now",
      },
    };
  }

  async retryRecordingProcessing(id: string): Promise<MutationResult<Recording>> {
    await wait(650);
    const recording = mockRecordings.find((item) => item.id === id) ?? recordingStatusFixtures.failed;
    return { ok: true, data: { ...recording, status: "processing" } };
  }

  async prepareDownload(id: string): Promise<DownloadResult> {
    await wait(450);
    const recording = mockRecordings.find((item) => item.id === id);
    if (!recording || recording.status === "expired") {
      return {
        state: "file_unavailable",
        error: {
          title: "File unavailable",
          body: "The file is no longer available.",
          referenceId: createSupportReference("DL"),
          retryable: false,
        },
      };
    }
    if (recording.sizeGb > legacyUsage.downloadGb.limit - legacyUsage.downloadGb.used) {
      return { state: "quota_insufficient" };
    }
    return { state: "started" };
  }
}

export const mockRepository = new MockSaveStreamRepository();
