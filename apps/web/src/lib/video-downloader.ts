// TikTok video downloader ("Free tools"): copy and the rules behind the
// public page, the signed-in "Download my videos" page and the nav.
// Backend contract: PRs #264 (service), DL2 (reports/blocklist), DL3 (owner
// downloads). The tool only serves TikTok's own downloadable file for videos
// whose creator allows downloads.
//
// No imports on purpose: scripts/video-downloader-audit.mjs loads this file
// directly with Node to test the rules below.

// --- API shapes --------------------------------------------------------------

export type VideoDownloaderStatus = {
  enabled: boolean;
  turnstile_after?: number;
  max_duration_seconds?: number;
  max_bytes?: number;
};

export type VideoDownloaderFile = {
  kind: string;
  format: string;
  label: string;
  watermarked: boolean;
  width?: number | null;
  height?: number | null;
  size_bytes?: number | null;
  /** Relative API path; prefix the API base. */
  download_url: string;
};

export type VideoDownloaderVideo = {
  id: string;
  username: string;
  author_name?: string | null;
  caption?: string | null;
  duration_seconds?: number | null;
  posted_at?: string | null;
  /** Relative API path; prefix the API base. */
  cover_url?: string | null;
  downloads_allowed_by_creator?: boolean;
};

export type VideoDownloaderResult = {
  video: VideoDownloaderVideo;
  files: VideoDownloaderFile[];
  expires_in_seconds: number;
  turnstile_required_next?: boolean;
};

/** The fields of an API error the downloader looks at (ApiError fits). */
export type DownloaderErrorInput = {
  status?: number;
  code?: string | undefined;
  serverMessage?: string | undefined;
  details?: unknown;
  requestId?: string | undefined;
  retryAfterSeconds?: number | null | undefined;
};

// --- Copy ----------------------------------------------------------------------

/** Under the link box. The design's notice, plus the "creator allows" rule. */
export const DOWNLOADER_NOTICE =
  "Only download videos you have the right to use. Respect creators: this tool only works when the creator allows downloads. Not affiliated with TikTok or ByteDance.";

/** Under the creator name on the result. */
export const DOWNLOADS_ALLOWED_LINE = "Public video · downloads allowed by the creator";

/** Tool switched off (status enabled:false, or the status call failed). */
export const TOOL_OFF_TITLE = "This tool isn't available right now";
export const TOOL_OFF_BODY =
  "The video downloader is switched off at the moment. Please check back later.";

export const LINK_EXPIRED_TEXT = "This download link has expired. Paste the TikTok link again.";

export const VIDEO_BLOCKED_TEXT =
  "This video was removed from the downloader after a request from its rights holder.";

export const NOT_YOUR_CHANNEL_TEXT = "This video isn't from one of your verified channels.";

export const FILE_RETENTION_ANSWER =
  "We don't store videos. They stream straight from TikTok to you.";

export const REPORT_RESPONSE_TIME = "within 3 business days";

// --- Status / nav ------------------------------------------------------------------

/**
 * The tool is on only when the status call succeeded with enabled:true. A
 * missing, failed or 404 status counts as off.
 */
export function downloaderEnabled(status: VideoDownloaderStatus | null | undefined): boolean {
  return status?.enabled === true;
}

/** "Free tools → Video downloader" in the public header/footer. */
export function showFreeToolsNav(status: VideoDownloaderStatus | null | undefined): boolean {
  return downloaderEnabled(status);
}

/**
 * The nav links and the tool are rendered on the server (and while the status
 * is loading) so search engines see them; they disappear once the status says
 * the tool is off or the status request fails.
 */
export function freeToolsVisible(
  status: VideoDownloaderStatus | null | undefined,
  loading: boolean,
): boolean {
  return loading || showFreeToolsNav(status);
}

/** The FAQ shown on /video-downloader; also its FAQPage JSON-LD (same text). */
export const VIDEO_DOWNLOADER_FAQ: readonly { question: string; answer: string }[] = [
  {
    question: "Is it free? Do I need an account?",
    answer: "Yes, it’s free and you don’t need to sign in.",
  },
  {
    question: "Which videos can I download?",
    answer:
      "Public videos where the creator allows downloads. If a creator has turned downloads off, we respect that and won’t fetch the video.",
  },
  { question: "Do you keep copies of the videos?", answer: FILE_RETENTION_ANSWER },
  {
    question: "How do I ask for a video to be removed?",
    answer:
      "Use the report / copyright removal form. We block links we receive valid requests for.",
  },
  {
    question: "Is SaveStream affiliated with TikTok?",
    answer:
      "No. SaveStream is an independent service and is not affiliated with TikTok or ByteDance.",
  },
];

export const VIDEO_DOWNLOADER_DESCRIPTION =
  "Save a public TikTok video as MP4 when its creator allows downloads. Free, no sign-up. Not affiliated with TikTok or ByteDance.";

/** JSON-LD for /video-downloader: the free web app, its FAQ and breadcrumbs. */
export function videoDownloaderStructuredData(siteUrl: string) {
  const url = `${siteUrl}/video-downloader`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebApplication",
        "@id": `${url}#app`,
        name: "SaveStream TikTok video downloader",
        url,
        description: VIDEO_DOWNLOADER_DESCRIPTION,
        applicationCategory: "MultimediaApplication",
        operatingSystem: "Web",
        browserRequirements: "Requires JavaScript.",
        isAccessibleForFree: true,
        offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
        publisher: { "@type": "Organization", name: "SaveStream", url: `${siteUrl}/` },
      },
      {
        "@type": "FAQPage",
        "@id": `${url}#faq`,
        mainEntity: VIDEO_DOWNLOADER_FAQ.map((item) => ({
          "@type": "Question",
          name: item.question,
          acceptedAnswer: { "@type": "Answer", text: item.answer },
        })),
      },
      breadcrumbData(siteUrl, [["Video downloader", url]]),
    ],
  };
}

/** BreadcrumbList starting at the home page. */
export function breadcrumbData(siteUrl: string, trail: readonly (readonly [string, string])[]) {
  return {
    "@type": "BreadcrumbList",
    itemListElement: [["Home", `${siteUrl}/`] as const, ...trail].map(([name, item], index) => ({
      "@type": "ListItem",
      position: index + 1,
      name,
      item,
    })),
  };
}

// --- Link checks ----------------------------------------------------------------------

/** A quick client-side check before calling the API (the server decides). */
export function looksLikeTikTokLink(value: string): boolean {
  const text = value.trim();
  if (!text || /\s/.test(text)) return false;
  const withScheme = /^[a-z][a-z\d+.-]*:\/\//i.test(text) ? text : `https://${text}`;
  try {
    const url = new URL(withScheme);
    if (url.protocol !== "https:" && url.protocol !== "http:") return false;
    const host = url.hostname.toLowerCase();
    return host === "tiktok.com" || host.endsWith(".tiktok.com");
  } catch {
    return false;
  }
}

// --- Files -----------------------------------------------------------------------------

/**
 * The public result shows ONE button: TikTok's own downloadable MP4. Any other
 * entry (audio, other formats) is ignored.
 */
export function pickPublicDownload(
  files: readonly VideoDownloaderFile[] | null | undefined,
): VideoDownloaderFile | null {
  return files?.find((file) => file.kind === "video" && file.format === "mp4") ?? null;
}

/** Owner results may carry "Original" and "MP4 (TikTok download)": show every video file. */
export function ownerDownloads(
  files: readonly VideoDownloaderFile[] | null | undefined,
): VideoDownloaderFile[] {
  return (files ?? []).filter((file) => file.kind === "video");
}

/** Button text for the public file, e.g. "Download MP4 · 4.2 MB". */
export function publicDownloadLabel(file: VideoDownloaderFile): string {
  const size = formatBytes(file.size_bytes);
  return size ? `Download MP4 · ${size}` : "Download MP4";
}

/** Button text for an owner file, e.g. "Download Original · 12 MB". */
export function ownerDownloadLabel(file: VideoDownloaderFile): string {
  const size = formatBytes(file.size_bytes);
  return size ? `Download ${file.label} · ${size}` : `Download ${file.label}`;
}

/** Prefix a relative API path (cover_url, download_url) with the API base. */
export function apiAssetUrl(apiBase: string, path: string | null | undefined): string | null {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path;
  const base = apiBase.replace(/\/$/, "");
  return `${base}${path.startsWith("/") ? "" : "/"}${path}`;
}

/** Owner file URL with a fresh grant: `<download_url>?grant=<grant>`. */
export function ownerFileUrl(apiBase: string, downloadUrl: string, grant: string): string {
  const absolute = apiAssetUrl(apiBase, downloadUrl) ?? downloadUrl;
  const url = new URL(absolute);
  url.searchParams.set("grant", grant);
  return url.toString();
}

/** download_url expires `expires_in_seconds` after the resolve. */
export function downloadLinkExpired(
  receivedAtMs: number,
  expiresInSeconds: number | null | undefined,
  nowMs: number,
): boolean {
  const ttl = typeof expiresInSeconds === "number" && expiresInSeconds > 0 ? expiresInSeconds : 600;
  return nowMs >= receivedAtMs + ttl * 1000;
}

// --- Owner downloads (grant refreshed before every request) ----------------------------

export type GrantRequester = (videoUrl: string) => Promise<{ grant: string }>;

/** Grant → owner resolve. A fresh grant every time; ownership is re-checked. */
export async function resolveOwnerVideo<T>(
  videoUrl: string,
  deps: {
    requestGrant: GrantRequester;
    resolve: (videoUrl: string, grant: string) => Promise<T>;
  },
): Promise<T> {
  const { grant } = await deps.requestGrant(videoUrl);
  return deps.resolve(videoUrl, grant);
}

/**
 * Owner file download: ask /grant again with the same video URL, then send the
 * browser to `<download_url>?grant=<fresh grant>`. Never reuses a grant.
 */
export async function downloadOwnerFile(
  videoUrl: string,
  file: Pick<VideoDownloaderFile, "download_url">,
  deps: { apiBase: string; requestGrant: GrantRequester; navigate: (url: string) => void },
): Promise<string> {
  const { grant } = await deps.requestGrant(videoUrl);
  const url = ownerFileUrl(deps.apiBase, file.download_url, grant);
  deps.navigate(url);
  return url;
}

// --- Errors → design states ---------------------------------------------------------------

export type DownloaderErrorKind =
  | "invalid"
  | "private"
  | "blocked"
  | "disabled"
  | "rate"
  | "captcha"
  | "too_big"
  | "expired"
  | "not_your_channel"
  | "no_verified_channel"
  | "tool_off"
  | "generic";

export type DownloaderErrorState = {
  kind: DownloaderErrorKind;
  /** Banner colour / icon. */
  tone: "err" | "warn" | "info";
  title: string;
  body: string;
  /** Show "Try again" (rate: once the countdown ends). */
  retry: boolean;
  retryAfterSeconds: number | null;
  /** Small mono line, e.g. "Error ID: …". */
  meta: string | null;
};

function record(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function retryAfter(error: DownloaderErrorInput): number | null {
  const fromDetails = record(error.details)["retry_after_seconds"];
  const seconds =
    typeof fromDetails === "number" && fromDetails > 0
      ? fromDetails
      : typeof error.retryAfterSeconds === "number" && error.retryAfterSeconds > 0
        ? error.retryAfterSeconds
        : null;
  return seconds === null ? null : Math.ceil(seconds);
}

const state = (
  kind: DownloaderErrorKind,
  tone: DownloaderErrorState["tone"],
  title: string,
  body: string,
  extra: Partial<DownloaderErrorState> = {},
): DownloaderErrorState => ({
  kind,
  tone,
  title,
  body,
  retry: false,
  retryAfterSeconds: null,
  meta: null,
  ...extra,
});

export const INVALID_LINK_STATE = state(
  "invalid",
  "err",
  "That doesn’t look like a video link",
  "Copy the link from the video’s Share menu. It usually looks like tiktok.com/@name/video/… or vm.tiktok.com/….",
);

export const LINK_EXPIRED_STATE = state(
  "expired",
  "warn",
  "Download link expired",
  LINK_EXPIRED_TEXT,
);

/** Map an API error (public resolve, owner grant/resolve) to a design state. */
export function downloaderErrorState(error: DownloaderErrorInput): DownloaderErrorState {
  const code = error.code ?? "";
  const reason = record(error.details)["reason"];
  switch (code) {
    case "INVALID_LINK":
      return INVALID_LINK_STATE;
    case "VIDEO_UNAVAILABLE":
      if (reason === "not_video") {
        return state(
          "private",
          "warn",
          "This link isn’t a video",
          "We can only fetch TikTok videos. Check the link, or copy it again from the video’s Share menu.",
        );
      }
      return state(
        "private",
        "warn",
        "This video is private or was removed",
        "We can only fetch public videos that are still online. Check the link, or ask the creator.",
      );
    case "VIDEO_BLOCKED":
      return state("blocked", "warn", "This video isn’t available here", VIDEO_BLOCKED_TEXT);
    case "DOWNLOADS_DISABLED":
      return state(
        "disabled",
        "info",
        "The creator turned off downloads for this video",
        "We respect the creator’s download setting, so we won’t download this video. You can still watch it in the app.",
      );
    case "RATE_LIMITED":
      return state(
        "rate",
        "warn",
        "Too many requests",
        "You’ve made a lot of downloads in a short time. Please wait a little and try again.",
        { retry: true, retryAfterSeconds: retryAfter(error) },
      );
    case "CAPTCHA_REQUIRED":
    case "CAPTCHA_FAILED":
      return state(
        "captcha",
        "info",
        "Quick check",
        "Please confirm you’re a person, then press Download again.",
      );
    case "VIDEO_TOO_LONG":
    case "VIDEO_TOO_LARGE":
      return state(
        "too_big",
        "err",
        "Something went wrong",
        error.serverMessage ?? "This video is too long or too large for the downloader.",
      );
    case "NOT_YOUR_CHANNEL":
      return state("not_your_channel", "warn", "Not one of your channels", NOT_YOUR_CHANNEL_TEXT);
    case "NO_VERIFIED_CHANNEL":
      return state(
        "no_verified_channel",
        "info",
        "Verify a channel first",
        "Download my videos works for channels you’ve verified. Add the short code to your TikTok bio to verify one.",
      );
    case "DOWNLOAD_LINK_EXPIRED":
      return LINK_EXPIRED_STATE;
    default:
      if (error.status === 410) return LINK_EXPIRED_STATE;
      return state(
        "generic",
        "err",
        "Something went wrong",
        "We couldn’t fetch this video right now. Please try again in a moment.",
        { retry: true, meta: error.requestId ? `Error ID: ${error.requestId}` : null },
      );
  }
}

/** The error asks for a Turnstile challenge before the next submit. */
export function needsTurnstile(error: DownloaderErrorInput): boolean {
  if (error.code === "CAPTCHA_FAILED") return true;
  return error.code === "CAPTCHA_REQUIRED" || record(error.details)["turnstile_required"] === true;
}

// --- Formatting -------------------------------------------------------------------------

/** "Try again in m:ss" countdown. */
export function formatCountdown(totalSeconds: number): string {
  const s = Math.max(0, Math.ceil(totalSeconds));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

export function retryLabel(remainingSeconds: number | null): string {
  return remainingSeconds && remainingSeconds > 0
    ? `Try again in ${formatCountdown(remainingSeconds)}`
    : "Try again";
}

/** Video length, e.g. 0:48 or 1:02:03. */
export function formatVideoDuration(seconds: number | null | undefined): string | null {
  if (typeof seconds !== "number" || !Number.isFinite(seconds) || seconds < 0) return null;
  const s = Math.round(seconds);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const pad = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s % 60)}` : `${m}:${pad(s % 60)}`;
}

export function formatBytes(bytes: number | null | undefined): string | null {
  if (typeof bytes !== "number" || !Number.isFinite(bytes) || bytes <= 0) return null;
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} KB`;
  const mb = bytes / (1024 * 1024);
  return `${mb < 10 ? mb.toFixed(1) : Math.round(mb)} MB`;
}
