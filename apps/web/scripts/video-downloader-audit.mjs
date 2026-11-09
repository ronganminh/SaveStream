// TikTok video downloader ("Free tools") on the website.
// Backend contract: PRs #264 (service), DL2 (reports/blocklist), DL3 (owner
// downloads). Product rules checked here:
// - every API error code maps to the right design state (VDInvalid, VDPrivate,
//   VDDisabled, VDRate with a countdown, VDGeneric, …);
// - the public result offers ONE "Download MP4" (TikTok's own file): no MP3,
//   no quality picker, and no "watermark" claims anywhere;
// - the Free tools nav links are hidden while the tool is switched off, and the
//   page stays out of the sitemap / noindex;
// - "Download my videos" asks for a fresh grant before every owner resolve
//   and every owner file download.
//
// The rules in src/lib/video-downloader.ts are tested by running them (Node
// strips the TypeScript types); the components are checked by source.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const root = process.cwd();
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const failures = [];
const test = async (label, fn) => {
  try {
    await fn();
    console.log(`ok   ${label}`);
  } catch (error) {
    console.log(`FAIL ${label}`);
    failures.push(`${label}: ${error.message}`);
  }
};
const block = (file, start, end) => {
  const source = read(file);
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  assert.ok(from >= 0 && to >= 0, `${file}: could not locate ${start}`);
  return source.slice(from, to);
};

const LIB = "src/lib/video-downloader.ts";
const PAGE = "src/components/public/video-downloader.tsx";
const REPORT = "src/components/public/video-downloader-report.tsx";
const MY_VIDEOS = "src/components/app/my-videos.tsx";
const ADMIN = "src/components/admin/video-downloader-admin.tsx";
const API = "src/api/video-downloader.ts";

const rules = await import(pathToFileURL(path.join(root, LIB)).href);
const {
  DOWNLOADER_NOTICE,
  DOWNLOADS_ALLOWED_LINE,
  FILE_RETENTION_ANSWER,
  REPORT_RESPONSE_TIME,
  LINK_EXPIRED_TEXT,
  VIDEO_BLOCKED_TEXT,
  NOT_YOUR_CHANNEL_TEXT,
  TOOL_OFF_TITLE,
  downloaderErrorState,
  needsTurnstile,
  pickPublicDownload,
  ownerDownloads,
  publicDownloadLabel,
  showFreeToolsNav,
  downloaderEnabled,
  looksLikeTikTokLink,
  formatCountdown,
  retryLabel,
  apiAssetUrl,
  ownerFileUrl,
  downloadLinkExpired,
  downloadOwnerFile,
  resolveOwnerVideo,
} = rules;

// --- Error code → design state --------------------------------------------------
const kind = (input) => downloaderErrorState(input).kind;

await test("INVALID_LINK → VDInvalid", () => {
  const s = downloaderErrorState({ status: 400, code: "INVALID_LINK" });
  assert.equal(s.kind, "invalid");
  assert.equal(s.title, "That doesn’t look like a video link");
});
await test("VIDEO_UNAVAILABLE (private/removed/not_video) → VDPrivate", () => {
  for (const reason of ["private", "removed", "not_video"]) {
    assert.equal(
      kind({ status: 404, code: "VIDEO_UNAVAILABLE", details: { reason } }),
      "private",
      reason,
    );
  }
  assert.equal(
    downloaderErrorState({ code: "VIDEO_UNAVAILABLE", details: { reason: "private" } }).title,
    "This video is private or was removed",
  );
});
await test("DOWNLOADS_DISABLED → VDDisabled", () => {
  const s = downloaderErrorState({ status: 403, code: "DOWNLOADS_DISABLED" });
  assert.equal(s.kind, "disabled");
  assert.equal(s.title, "The creator turned off downloads for this video");
});
await test("RATE_LIMITED → VDRate with details.retry_after_seconds", () => {
  const s = downloaderErrorState({
    status: 429,
    code: "RATE_LIMITED",
    details: { retry_after_seconds: 120 },
  });
  assert.equal(s.kind, "rate");
  assert.equal(s.retryAfterSeconds, 120);
  assert.equal(retryLabel(s.retryAfterSeconds), "Try again in 2:00");
});
await test("RATE_LIMITED falls back to the Retry-After header", () => {
  const s = downloaderErrorState({ status: 429, code: "RATE_LIMITED", retryAfterSeconds: 75 });
  assert.equal(s.retryAfterSeconds, 75);
  assert.equal(retryLabel(75), "Try again in 1:15");
  assert.equal(retryLabel(0), "Try again");
  assert.equal(retryLabel(null), "Try again");
  assert.equal(formatCountdown(9), "0:09");
});
await test("CAPTCHA_REQUIRED → Turnstile", () => {
  const error = { status: 400, code: "CAPTCHA_REQUIRED", details: { turnstile_required: true } };
  assert.equal(kind(error), "captcha");
  assert.equal(needsTurnstile(error), true);
  assert.equal(needsTurnstile({ code: "INVALID_LINK" }), false);
});
await test("VIDEO_BLOCKED (451) → VDPrivate-style rights-holder message", () => {
  const s = downloaderErrorState({ status: 451, code: "VIDEO_BLOCKED" });
  assert.equal(s.kind, "blocked");
  assert.equal(s.tone, "warn");
  assert.equal(
    s.body,
    "This video was removed from the downloader after a request from its rights holder.",
  );
  assert.equal(VIDEO_BLOCKED_TEXT, s.body);
});
await test("VIDEO_TOO_LONG / VIDEO_TOO_LARGE → generic with the server message", () => {
  for (const code of ["VIDEO_TOO_LONG", "VIDEO_TOO_LARGE"]) {
    const s = downloaderErrorState({ status: 413, code, serverMessage: "Max 10 minutes." });
    assert.equal(s.kind, "too_big");
    assert.equal(s.title, "Something went wrong");
    assert.equal(s.body, "Max 10 minutes.");
  }
});
await test("DOWNLOADER_UNAVAILABLE / BUSY / DISABLED (503) → VDGeneric", () => {
  for (const code of ["DOWNLOADER_UNAVAILABLE", "DOWNLOADER_BUSY", "DOWNLOADER_DISABLED"]) {
    const s = downloaderErrorState({ status: 503, code, requestId: "req_1" });
    assert.equal(s.kind, "generic", code);
    assert.equal(s.retry, true);
    assert.equal(s.meta, "Error ID: req_1");
  }
  assert.equal(kind({ status: 0, code: "NETWORK_ERROR" }), "generic");
  assert.equal(kind({}), "generic");
});
await test("HTTP 410 → link expired", () => {
  const s = downloaderErrorState({ status: 410 });
  assert.equal(s.kind, "expired");
  assert.equal(s.body, "This download link has expired. Paste the TikTok link again.");
  assert.equal(LINK_EXPIRED_TEXT, s.body);
});
await test("owner errors: NOT_YOUR_CHANNEL / NO_VERIFIED_CHANNEL", () => {
  const s = downloaderErrorState({ status: 403, code: "NOT_YOUR_CHANNEL" });
  assert.equal(s.kind, "not_your_channel");
  assert.equal(s.body, "This video isn't from one of your verified channels.");
  assert.equal(NOT_YOUR_CHANNEL_TEXT, s.body);
  assert.equal(kind({ status: 403, code: "NO_VERIFIED_CHANNEL" }), "no_verified_channel");
});
await test("download link expiry (10 minutes)", () => {
  assert.equal(downloadLinkExpired(0, 600, 599_000), false);
  assert.equal(downloadLinkExpired(0, 600, 600_000), true);
  assert.equal(downloadLinkExpired(0, undefined, 600_000), true);
});
await test("client link check", () => {
  for (const ok of [
    "https://www.tiktok.com/@sample.creator/video/7430000000000000000",
    "https://vm.tiktok.com/ZMabc123/",
    "tiktok.com/@a/video/1",
  ]) {
    assert.equal(looksLikeTikTokLink(ok), true, ok);
  }
  for (const bad of [
    "",
    "my link to the video",
    "https://example.com/tiktok.com/x",
    "ftp://tiktok.com/a",
  ]) {
    assert.equal(looksLikeTikTokLink(bad), false, bad);
  }
});
await test("page maps API errors through downloaderErrorState and shows the countdown", () => {
  const page = read(PAGE);
  assert.ok(page.includes("downloaderErrorState("));
  assert.ok(page.includes('useCountdown(error.kind === "rate"'));
  assert.ok(page.includes("retryLabel(remaining)"));
  assert.ok(page.includes("TurnstileWidget"));
  assert.ok(page.includes("result.turnstile_required_next"));
  assert.ok(page.includes("turnstileSiteKey"), "no widget without a site key");
});
await test("ApiError keeps the Retry-After header", () => {
  const errors = read("src/api/errors.ts");
  assert.ok(errors.includes('response.headers.get("Retry-After")'));
  assert.ok(errors.includes("readonly retryAfterSeconds"));
});

// --- One MP4, no MP3, no watermark claims ------------------------------------------
const files = [
  { kind: "audio", format: "mp3", label: "MP3", watermarked: false, download_url: "/a.mp3" },
  {
    kind: "video",
    format: "mp4",
    label: "MP4",
    watermarked: true,
    size_bytes: 4_404_019,
    download_url: "/v1/public/video-downloader/files/abc",
  },
  { kind: "video", format: "mp4", label: "MP4 HD", watermarked: false, download_url: "/hd" },
];
await test("public result: exactly one MP4, never audio", () => {
  const file = pickPublicDownload(files);
  assert.equal(file.download_url, "/v1/public/video-downloader/files/abc");
  assert.equal(pickPublicDownload([files[0]]), null);
  assert.equal(pickPublicDownload(undefined), null);
  assert.equal(publicDownloadLabel(file), "Download MP4 · 4.2 MB");
  assert.equal(publicDownloadLabel({ ...file, size_bytes: null }), "Download MP4");
});
await test("public page renders a single download button and no MP3/quality picker", () => {
  const page = read(PAGE);
  const result = block(PAGE, "function PublicResult(", "function DownloaderInfo(");
  assert.equal((result.match(/<PublicDownloadButton/g) ?? []).length, 1);
  assert.ok(result.includes("pickPublicDownload(result.files)"));
  assert.ok(!/\.files\.map\(/.test(result), "public files must not be listed");
  assert.ok(!/mp3|audio/i.test(page), "no MP3 / audio download on the public page");
  assert.ok(!/HD · 1080p|SD · 720p|radiogroup/.test(page), "no quality picker");
  assert.ok(page.includes("DOWNLOADS_ALLOWED_LINE"));
  assert.equal(DOWNLOADS_ALLOWED_LINE, "Public video · downloads allowed by the creator");
});
await test("owner result shows every video file as its own button", () => {
  const owner = ownerDownloads([
    { kind: "video", format: "mp4", label: "Original", watermarked: false, download_url: "/o" },
    {
      kind: "video",
      format: "mp4",
      label: "MP4 (TikTok download)",
      watermarked: true,
      download_url: "/t",
    },
    files[0],
  ]);
  assert.deepEqual(
    owner.map((file) => file.label),
    ["Original", "MP4 (TikTok download)"],
  );
  assert.ok(read(MY_VIDEOS).includes("ownerDownloads(phase.result.files).map("));
});
await test("no watermark / 'download any video' claims in downloader copy", () => {
  const userFacing = [PAGE, REPORT, MY_VIDEOS, ADMIN, "src/components/app-pages.tsx"];
  for (const file of userFacing) {
    const text = read(file);
    assert.ok(!/watermark/i.test(text), `${file}: mentions "watermark"`);
  }
  // The rules file only carries the API's `watermarked` flag, never copy about it.
  const lib = read(LIB).replace(/watermarked(\??): boolean;/g, "");
  assert.ok(!/watermark/i.test(lib), `${LIB}: mentions "watermark" outside the type`);
  for (const file of [...userFacing, LIB]) {
    const text = read(file);
    assert.ok(!/download any (tiktok )?video/i.test(text), `${file}: "download any video"`);
    assert.ok(!/anyone[’']s videos/i.test(text), `${file}: "anyone's videos"`);
    assert.ok(!/\[[A-Z]{2,}(?: [A-Z]{2,})*\]/.test(text), `${file}: bracketed placeholder`);
  }
});
await test("copy: notice, FAQ retention and report response time", () => {
  assert.ok(
    DOWNLOADER_NOTICE.startsWith(
      "Only download videos you have the right to use. Respect creators: this tool only works when the creator allows downloads.",
    ),
  );
  assert.equal(
    FILE_RETENTION_ANSWER,
    "We don't store videos. They stream straight from TikTok to you.",
  );
  assert.equal(REPORT_RESPONSE_TIME, "within 3 business days");
  assert.ok(read(PAGE).includes("FILE_RETENTION_ANSWER"));
  assert.ok(read(REPORT).includes("REPORT_RESPONSE_TIME"));
});
await test("asset URLs are prefixed with the API base", () => {
  assert.equal(
    apiAssetUrl("https://api.savestream.online", "/v1/public/video-downloader/covers/1.jpg"),
    "https://api.savestream.online/v1/public/video-downloader/covers/1.jpg",
  );
  assert.equal(apiAssetUrl("https://api.savestream.online", null), null);
  const page = read(PAGE);
  assert.ok(page.includes("apiAssetUrl(apiBaseUrl, video.cover_url)"));
  assert.ok(page.includes("apiAssetUrl(apiBaseUrl, file.download_url)"));
});

// --- Tool switched off: hidden nav, noindex, no sitemap -------------------------------
await test("Free tools nav is hidden unless status says enabled:true", () => {
  assert.equal(showFreeToolsNav({ enabled: true }), true);
  assert.equal(showFreeToolsNav({ enabled: false }), false);
  assert.equal(showFreeToolsNav(null), false, "status request failed / 404");
  assert.equal(showFreeToolsNav(undefined), false, "status still loading");
  assert.equal(downloaderEnabled({ enabled: "true" }), false);
});
await test("header and footer gate the Free tools links on the status", () => {
  const pages = "src/components/app-pages.tsx";
  const header = block(pages, "export function PublicHeader()", "function formatSampleDuration(");
  assert.ok(header.includes("showFreeToolsNav(useVideoDownloaderStatus().status)"));
  const gated = header.split("{showFreeTools && (");
  assert.equal(gated.length, 3, "desktop nav and mobile sheet are both gated");
  assert.ok(!gated[0].includes("freeToolLinks"), "no ungated Free tools link");
  const footer = block(pages, "export function PublicFooter()", "const channelStates = [");
  assert.ok(footer.includes("showFreeToolsNav(useVideoDownloaderStatus().status)"));
  const beforeGate = footer.slice(0, footer.indexOf("if (showFreeTools)"));
  assert.ok(!beforeGate.includes("/video-downloader"), "footer link outside the gate");
  assert.ok(footer.includes('["/video-downloader/report",'));
});
await test("status hook treats errors and loading as off", () => {
  const hook = read("src/hooks/use-video-downloader.ts");
  assert.ok(hook.includes("downloaderEnabled(query.data)"));
  assert.ok(hook.includes("retry: false"));
  assert.ok(read(PAGE).includes("<ToolOffNotice"));
  assert.equal(TOOL_OFF_TITLE, "This tool isn't available right now");
});
await test("page is noindex and not in the static sitemap", () => {
  const config = read("src/lib/app-config.ts");
  const indexable = block("src/lib/app-config.ts", "PUBLIC_INDEXABLE_PATHS", "];");
  assert.ok(!indexable.includes("/video-downloader"));
  assert.ok(!read("public/sitemap.xml").includes("/video-downloader"));
  assert.ok(
    read("src/routes/video-downloader.tsx").includes('publicMeta(\n      "/video-downloader"'),
  );
  assert.ok(config.includes('"/my-videos"'), "/my-videos needs a session");
});
await test("routes and links", () => {
  assert.ok(
    read("src/routes/video-downloader_.report.tsx").includes('"/video-downloader_/report"'),
  );
  assert.ok(read(PAGE).includes('REPORT_PATH = "/video-downloader/report"'));
  assert.ok(read("src/components/app-pages.tsx").includes('ownership === "verified" && ('));
  assert.ok(read("src/components/app-components.tsx").includes('navigate({ to: "/my-videos" })'));
  const sidebar = block("src/components/app-components.tsx", '{ to: "/help"', "];");
  assert.ok(!sidebar.includes("video-downloader"), "no sidebar item for the public tool");
});

// --- Owner downloads: fresh grant before every request ----------------------------------
await test("owner resolve asks for a grant first", async () => {
  const calls = [];
  const result = await resolveOwnerVideo("https://www.tiktok.com/@me/video/1", {
    requestGrant: async (url) => {
      calls.push(["grant", url]);
      return { grant: "g1" };
    },
    resolve: async (url, grant) => {
      calls.push(["resolve", url, grant]);
      return { ok: true };
    },
  });
  assert.deepEqual(result, { ok: true });
  assert.deepEqual(calls, [
    ["grant", "https://www.tiktok.com/@me/video/1"],
    ["resolve", "https://www.tiktok.com/@me/video/1", "g1"],
  ]);
});
await test("owner file download refreshes the grant before EVERY navigation", async () => {
  const events = [];
  let n = 0;
  const deps = {
    apiBase: "https://api.savestream.online",
    requestGrant: async (url) => {
      n += 1;
      events.push(["grant", url]);
      return { grant: `fresh-${n}` };
    },
    navigate: (url) => events.push(["navigate", url]),
  };
  const video = "https://www.tiktok.com/@me/video/1";
  await downloadOwnerFile(
    video,
    { download_url: "/v1/public/video-downloader/files/o?sig=x" },
    deps,
  );
  await downloadOwnerFile(video, { download_url: "/v1/public/video-downloader/files/t" }, deps);
  assert.deepEqual(
    events.map(([type]) => type),
    ["grant", "navigate", "grant", "navigate"],
  );
  assert.equal(events[0][1], video, "grant uses the same video URL");
  assert.equal(
    events[1][1],
    "https://api.savestream.online/v1/public/video-downloader/files/o?sig=x&grant=fresh-1",
  );
  assert.equal(
    events[3][1],
    "https://api.savestream.online/v1/public/video-downloader/files/t?grant=fresh-2",
  );
});
await test("a failed grant never navigates", async () => {
  let navigated = false;
  await assert.rejects(
    downloadOwnerFile(
      "v",
      { download_url: "/f" },
      {
        apiBase: "https://api.savestream.online",
        requestGrant: async () => {
          throw new Error("NOT_YOUR_CHANNEL");
        },
        navigate: () => {
          navigated = true;
        },
      },
    ),
  );
  assert.equal(navigated, false);
  assert.equal(ownerFileUrl("https://api.x", "/f?grant=old", "new"), "https://api.x/f?grant=new");
});
await test("my-videos page uses the grant helpers and never stores a grant", () => {
  const page = read(MY_VIDEOS);
  assert.ok(page.includes("resolveOwnerVideo(link, {"));
  assert.ok(page.includes("downloadOwnerFile(videoUrl, file, {"));
  assert.ok(page.includes("videoDownloaderApi.grant("));
  assert.ok(!/useState<[^>]*grant/i.test(page) && !/setGrant/.test(page), "grant kept in state");
  assert.ok(page.includes("<VerifyChannelCta />"));
  assert.ok(page.includes("<ToolOffNotice"));
  const api = read(API);
  assert.ok(api.includes('"/v1/me/video-downloads/grant"'));
  assert.ok(api.includes('"/v1/public/video-downloader/owner/resolve"'));
  assert.ok(api.includes('"/v1/me/video-downloads/channels"'));
});

// --- Admin -------------------------------------------------------------------------------
await test("admin Downloader tab uses step-up for writes", () => {
  const admin = read(ADMIN);
  assert.ok(admin.includes("adminFoundationApi.stepUp(password, totp)"));
  const api = block(
    "src/repositories/admin-api.ts",
    "export const adminVideoDownloaderApi",
    "\n};",
  );
  assert.equal((api.match(/stepUpHeaders\(stepUpToken\)/g) ?? []).length, 2);
  assert.ok(api.includes("/v1/admin/video-downloader/blocklist?active_only="));
  assert.ok(api.includes("/v1/admin/video-downloader/reports?limit="));
  const safety = read("src/components/admin/safety-d8.tsx");
  assert.ok(safety.includes('<AdminTabsTrigger value="downloader">Downloader</AdminTabsTrigger>'));
});

if (failures.length) {
  console.error(`\nVideo downloader audit failed:\n- ${failures.join("\n- ")}`);
  process.exit(1);
}
console.log("\nVideo downloader audit passed.");
