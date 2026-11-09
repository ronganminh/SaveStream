import { apiClient } from "@/api/client";
import type { VideoDownloaderResult, VideoDownloaderStatus } from "@/lib/video-downloader";

export type { VideoDownloaderResult, VideoDownloaderStatus } from "@/lib/video-downloader";

export type VideoDownloaderReportRequest = {
  video_url: string;
  reporter_name: string;
  reporter_email: string;
  relationship: "creator" | "rights_holder" | "agent" | "other";
  reason: "copyright" | "privacy" | "other";
  details: string;
  good_faith: true;
  turnstile_token?: string | null;
};

export type VideoDownloaderChannel = {
  watch_id: string;
  username: string;
  display_name?: string | null;
  avatar_url?: string | null;
  verified: boolean;
};

// Backend: PR #264 (service), DL2 (reports/blocklist), DL3 (owner downloads).
// nginx routes the downloader prefix to its own container on the same API host.
export const videoDownloaderApi = {
  /** GET /v1/public/video-downloader/status — a failure or 404 means "off". */
  status() {
    return apiClient.get<VideoDownloaderStatus>("/v1/public/video-downloader/status", {
      skipAuth: true,
    });
  },

  /** POST /v1/public/video-downloader/resolve — anonymous. */
  resolve(url: string, turnstileToken?: string | null) {
    return apiClient.post<VideoDownloaderResult>("/v1/public/video-downloader/resolve", {
      skipAuth: true,
      json: { url, ...(turnstileToken ? { turnstile_token: turnstileToken } : {}) },
    });
  },

  /** POST /v1/public/video-downloader-reports → 201 {reference}. Blocks the video at once. */
  report(payload: VideoDownloaderReportRequest) {
    return apiClient.post<{ reference: string }>("/v1/public/video-downloader-reports", {
      skipAuth: true,
      json: payload,
    });
  },

  /** GET /v1/me/video-downloads/channels — the user's verified, unblocked channels. */
  myChannels() {
    return apiClient.get<{ items: VideoDownloaderChannel[] }>("/v1/me/video-downloads/channels");
  },

  /** POST /v1/me/video-downloads/grant — 60 s grant; fetch a new one before every owner call. */
  grant(url: string) {
    return apiClient.post<{ grant: string; expires_in_seconds: number }>(
      "/v1/me/video-downloads/grant",
      { json: { url } },
    );
  },

  /** POST /v1/public/video-downloader/owner/resolve with a fresh grant. */
  ownerResolve(url: string, grant: string) {
    return apiClient.post<VideoDownloaderResult>("/v1/public/video-downloader/owner/resolve", {
      skipAuth: true,
      json: { url, grant },
    });
  },
};
