import { useState, type FormEvent } from "react";
import { Link } from "@tanstack/react-router";
import { BadgeCheck, Download, Link2, RotateCw, ShieldCheck } from "lucide-react";

import { ApiError } from "@/api/errors";
import { videoDownloaderApi, type VideoDownloaderChannel } from "@/api/video-downloader";
import { AppShell, AvatarCircle, ErrorState, PageHeader } from "@/components/app-components";
import {
  DownloaderErrorBanner,
  DownloaderLoading,
  DownloaderResultCard,
  ToolOffNotice,
} from "@/components/public/video-downloader";
import { Button } from "@/components/ui/button";
import { useMyDownloadChannels, useVideoDownloaderStatus } from "@/hooks/use-video-downloader";
import { apiBaseUrl } from "@/lib/app-config";
import { cn } from "@/lib/utils";
import {
  INVALID_LINK_STATE,
  downloadOwnerFile,
  downloaderErrorState,
  looksLikeTikTokLink,
  ownerDownloadLabel,
  ownerDownloads,
  resolveOwnerVideo,
  type DownloaderErrorState,
  type VideoDownloaderFile,
  type VideoDownloaderResult,
} from "@/lib/video-downloader";

const card = "rounded-[20px] border bg-surface shadow-card";

const toErrorState = (error: unknown) =>
  downloaderErrorState(error instanceof ApiError ? error : {});

function initialsOf(channel: VideoDownloaderChannel) {
  const source = channel.display_name || channel.username;
  return (source.replace(/[^a-z0-9]/gi, "").slice(0, 2) || "TT").toUpperCase();
}

function VerifyChannelCta() {
  return (
    <section
      className={cn(card, "flex flex-col items-center gap-3 p-8 text-center")}
      aria-labelledby="mv-verify"
    >
      <span className="grid size-14 place-items-center rounded-[18px] bg-primary-subtle text-accent-ink">
        <ShieldCheck className="size-7" />
      </span>
      <h2 id="mv-verify" className="text-[22px] font-extrabold tracking-[-.02em]">
        Verify a channel to download your videos
      </h2>
      <p className="m-0 max-w-[480px] text-muted-foreground">
        Download my videos works for TikTok channels you’ve verified on SaveStream. Open one of your
        channels and add the short code to your TikTok bio to verify it.
      </p>
      <Button asChild>
        <Link to="/channels">Go to your channels</Link>
      </Button>
    </section>
  );
}

function ChannelList({ channels }: { channels: VideoDownloaderChannel[] }) {
  return (
    <section className="flex flex-col gap-3" aria-labelledby="mv-channels">
      <h2 id="mv-channels" className="text-lg font-extrabold">
        Your verified channels
      </h2>
      <ul className="m-0 grid list-none gap-3 p-0 [grid-template-columns:repeat(auto-fill,minmax(min(300px,100%),1fr))]">
        {channels.map((channel) => (
          <li key={channel.watch_id} className={cn(card, "flex items-center gap-3 p-4")}>
            <AvatarCircle src={channel.avatar_url} initials={initialsOf(channel)} />
            <div className="flex min-w-0 flex-col">
              <b className="truncate">@{channel.username.replace(/^@/, "")}</b>
              {channel.display_name ? (
                <span className="truncate text-xs text-muted-foreground">
                  {channel.display_name}
                </span>
              ) : null}
            </div>
            <span className="ml-auto inline-flex items-center gap-1 rounded-full bg-success-subtle px-2 py-0.5 text-xs font-bold text-success">
              <BadgeCheck className="size-3.5" />
              Verified
            </span>
          </li>
        ))}
      </ul>
    </section>
  );
}

type Phase =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "error"; error: DownloaderErrorState }
  | { kind: "result"; result: VideoDownloaderResult; videoUrl: string };

function OwnerDownloader() {
  const [url, setUrl] = useState("");
  const [phase, setPhase] = useState<Phase>({ kind: "idle" });
  const [downloading, setDownloading] = useState<string | null>(null);
  const [downloadError, setDownloadError] = useState<DownloaderErrorState | null>(null);

  const run = async () => {
    const link = url.trim();
    if (!looksLikeTikTokLink(link)) {
      setPhase({ kind: "error", error: INVALID_LINK_STATE });
      return;
    }
    setPhase({ kind: "loading" });
    setDownloadError(null);
    try {
      // A fresh grant before every owner resolve: ownership is re-checked each time.
      const result = await resolveOwnerVideo(link, {
        requestGrant: (videoUrl) => videoDownloaderApi.grant(videoUrl),
        resolve: (videoUrl, grant) => videoDownloaderApi.ownerResolve(videoUrl, grant),
      });
      setPhase({ kind: "result", result, videoUrl: link });
    } catch (error) {
      setPhase({ kind: "error", error: toErrorState(error) });
    }
  };

  const download = async (videoUrl: string, file: VideoDownloaderFile) => {
    setDownloading(file.download_url);
    setDownloadError(null);
    try {
      // A fresh grant before every file download, then a plain navigation.
      await downloadOwnerFile(videoUrl, file, {
        apiBase: apiBaseUrl,
        requestGrant: (link) => videoDownloaderApi.grant(link),
        navigate: (target) => window.location.assign(target),
      });
    } catch (error) {
      setDownloadError(toErrorState(error));
    } finally {
      setDownloading(null);
    }
  };

  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (phase.kind !== "loading") void run();
  };

  const reset = () => {
    setUrl("");
    setPhase({ kind: "idle" });
    setDownloadError(null);
  };

  const verifyAction = (error: DownloaderErrorState) =>
    error.kind === "no_verified_channel" ? (
      <Button size="sm" asChild>
        <Link to="/channels">Verify a channel</Link>
      </Button>
    ) : undefined;

  return (
    <section className="flex flex-col gap-4" aria-labelledby="mv-form">
      <h2 id="mv-form" className="text-lg font-extrabold">
        Paste a link to one of your videos
      </h2>
      <form
        className={cn(card, "flex flex-wrap gap-2.5 p-2.5")}
        aria-label="Video link"
        noValidate
        onSubmit={submit}
      >
        <label htmlFor="mv-url" className="relative min-w-0 flex-[999_1_320px]">
          <span className="sr-only">Video link</span>
          <Link2
            aria-hidden
            className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-muted-foreground"
          />
          <input
            id="mv-url"
            type="url"
            inputMode="url"
            autoComplete="off"
            placeholder="https://www.tiktok.com/@yourchannel/video/…"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
            className="h-[52px] w-full rounded-[14px] bg-transparent pl-[50px] pr-3 text-base outline-none placeholder:text-muted-foreground focus-visible:ring-2 focus-visible:ring-ring"
          />
        </label>
        <Button
          type="submit"
          size="lg"
          className="h-[52px] flex-[1_1_160px]"
          disabled={phase.kind === "loading"}
        >
          <Download className="size-5" />
          {phase.kind === "loading" ? "Fetching…" : "Get video"}
        </Button>
      </form>
      <p className="m-0 text-sm text-muted-foreground">
        Only links to videos from the verified channels above work here.
      </p>

      {phase.kind === "error" ? (
        <DownloaderErrorBanner
          error={phase.error}
          onRetry={() => void run()}
          onReset={reset}
          action={verifyAction(phase.error)}
        />
      ) : null}
      {phase.kind === "loading" ? <DownloaderLoading /> : null}
      {phase.kind === "result" ? (
        <>
          {downloadError ? (
            <DownloaderErrorBanner
              error={downloadError}
              onRetry={() => setDownloadError(null)}
              action={verifyAction(downloadError)}
            />
          ) : null}
          <DownloaderResultCard
            result={phase.result}
            subtitle="Your verified channel"
            actions={ownerDownloads(phase.result.files).map((file, index) => (
              <Button
                key={file.download_url}
                size="lg"
                variant={index === 0 ? "default" : "outline"}
                disabled={downloading !== null}
                onClick={() => void download(phase.videoUrl, file)}
              >
                <Download className="size-[18px]" />
                {downloading === file.download_url ? "Preparing…" : ownerDownloadLabel(file)}
              </Button>
            ))}
            footer={
              <Button type="button" variant="ghost" className="self-start" onClick={reset}>
                <RotateCw className="size-4" />
                Download another
              </Button>
            }
          />
        </>
      ) : null}
    </section>
  );
}

export function MyVideosPage() {
  const { enabled, loading } = useVideoDownloaderStatus();
  const channelsQuery = useMyDownloadChannels(enabled);
  const channelsError = channelsQuery.error instanceof ApiError ? channelsQuery.error : null;
  const channels = channelsQuery.data ?? [];
  const noVerifiedChannel =
    channelsError?.code === "NO_VERIFIED_CHANNEL" || (channelsQuery.isSuccess && !channels.length);

  let body;
  if (loading || (enabled && channelsQuery.isPending)) {
    body = <div className={cn(card, "h-40 animate-pulse")} aria-busy="true" />;
  } else if (!enabled || channelsError?.code === "DOWNLOADER_DISABLED") {
    body = <ToolOffNotice homeTo="/overview" />;
  } else if (noVerifiedChannel) {
    body = <VerifyChannelCta />;
  } else if (channelsQuery.isError) {
    body = (
      <ErrorState
        title="Could not load your channels"
        body="Please try again in a moment."
        onRetry={() => void channelsQuery.refetch()}
      />
    );
  } else {
    body = (
      <div className="flex flex-col gap-8">
        <ChannelList channels={channels} />
        <OwnerDownloader />
      </div>
    );
  }

  return (
    <AppShell>
      <PageHeader
        title="Download my videos"
        subtitle="Save videos from the TikTok channels you’ve verified on SaveStream."
      />
      {body}
    </AppShell>
  );
}
