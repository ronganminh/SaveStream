import { useCallback, useState } from "react";
import { toast } from "sonner";

import {
  artifactActionErrorMessage,
  saveSignedFile,
  useRecordingDownloadMutation,
} from "@/hooks/use-recording-mutations";

/** Storage answered the signed link with an error status (e.g. R2 503). */
export class StorageResponseError extends Error {
  constructor(readonly status: number) {
    super(`Storage answered ${status}`);
  }
}

export type DownloadPhase = "idle" | "preparing" | "started" | "failed";

type DownloadableRecording = { id: string; title: string; handle: string; size?: string };

const CHECK_TIMEOUT_MS = 10_000;
const STORAGE_RETRY_DELAY_MS = 1_500;

/**
 * Ask storage for the first byte of the signed file, so an error such as an
 * R2 503 shows up here (with a retry) instead of silently failing in the
 * browser's download list. A network or CORS failure cannot be told apart
 * from a working link, so it does not block the download ("unknown").
 */
export async function checkSignedFile(
  url: string,
  fetchImpl: typeof fetch = fetch,
): Promise<"ok" | "unknown" | number> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), CHECK_TIMEOUT_MS);
  try {
    const response = await fetchImpl(url, {
      headers: { Range: "bytes=0-0" },
      cache: "no-store",
      signal: controller.signal,
    });
    void response.body?.cancel().catch(() => undefined);
    return response.ok ? "ok" : response.status;
  } catch {
    return "unknown";
  } finally {
    clearTimeout(timer);
  }
}

export function downloadErrorMessage(error: unknown): string {
  if (error instanceof StorageResponseError) {
    if (error.status === 404) {
      return "This recording file is no longer available. It may have expired or been cleaned up.";
    }
    if (error.status === 403) {
      return "The download link was refused or has expired. Try again for a fresh link.";
    }
    return "Storage is temporarily unavailable. Please try again in a moment.";
  }
  return artifactActionErrorMessage(error);
}

/**
 * Download a recording with visible feedback: "Preparing download…" while the
 * link is created and checked, "Download started" once the browser has the
 * file, or an error with a "Try again" button. A storage 5xx is retried once
 * with a fresh link before giving up.
 */
export function useRecordingDownload() {
  const mutation = useRecordingDownloadMutation();
  const [phase, setPhase] = useState<DownloadPhase>("idle");

  const start = useCallback(
    async (recording: DownloadableRecording, options: { onError?: () => void } = {}) => {
      const toastId = `download-${recording.id}`;
      const label = `${recording.handle} — ${recording.title}`;
      setPhase("preparing");
      toast.loading("Preparing download…", { id: toastId, description: label });
      try {
        const signedLink = async () =>
          (await mutation.mutateAsync({ recordingId: recording.id, saveAs: true })).download.url;
        let url = await signedLink();
        let check = await checkSignedFile(url);
        if (typeof check === "number" && check >= 500) {
          await new Promise((resolve) => setTimeout(resolve, STORAGE_RETRY_DELAY_MS));
          url = await signedLink();
          check = await checkSignedFile(url);
        }
        if (typeof check === "number") throw new StorageResponseError(check);

        saveSignedFile(url);
        setPhase("started");
        toast.success("Download started", {
          id: toastId,
          description: `${recording.size ? `${recording.size} · ` : ""}Check your browser's downloads.`,
          duration: 6_000,
        });
      } catch (error) {
        setPhase("failed");
        toast.error("Download failed", {
          id: toastId,
          description: downloadErrorMessage(error),
          duration: 15_000,
          action: { label: "Try again", onClick: () => void start(recording, options) },
        });
        options.onError?.();
      }
    },
    [mutation],
  );

  return { start, phase, isPreparing: phase === "preparing" };
}
