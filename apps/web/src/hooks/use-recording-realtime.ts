import { useEffect, useRef, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";

import type { RecordingStatusValue } from "@/api/types";
import { domainQueryKeys } from "@/hooks/use-domain-data";
import { isDemoMode } from "@/lib/app-config";
import { repositories } from "@/repositories";

export type RecordingRealtimeState =
  | "idle"
  | "connecting"
  | "connected"
  | "reconnecting"
  | "fallback"
  | "ended";

const terminalStatuses = new Set<RecordingStatusValue>([
  "completed",
  "failed",
  "stopped",
]);

export function isTerminalRecordingStatus(status: RecordingStatusValue) {
  return terminalStatuses.has(status);
}

function reconnectDelay(attempt: number) {
  return Math.min(1000 * 2 ** Math.min(attempt, 3), 8000);
}

async function waitForReconnect(ms: number, signal: AbortSignal) {
  await new Promise<void>((resolve) => {
    if (signal.aborted) {
      resolve();
      return;
    }
    const timer = window.setTimeout(resolve, ms);
    signal.addEventListener(
      "abort",
      () => {
        window.clearTimeout(timer);
        resolve();
      },
      { once: true },
    );
  });
}

export function useRecordingRealtime(
  recordingId: string | null | undefined,
  backendStatus: RecordingStatusValue | null | undefined,
) {
  const queryClient = useQueryClient();
  const [state, setState] = useState<RecordingRealtimeState>("idle");
  const [lastEventAt, setLastEventAt] = useState<number | null>(null);
  const lastEventIdRef = useRef<string | null>(null);

  useEffect(() => {
    if (
      !recordingId ||
      !backendStatus ||
      isDemoMode ||
      isTerminalRecordingStatus(backendStatus)
    ) {
      setState(
        backendStatus && isTerminalRecordingStatus(backendStatus) ? "ended" : "idle",
      );
      return;
    }

    const controller = new AbortController();
    let reconnectAttempt = 0;

    const refreshQueries = async () => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.recording(recordingId) }),
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.recordings }),
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.activeRecording }),
      ]);
    };

    const run = async () => {
      while (!controller.signal.aborted) {
        setState(reconnectAttempt === 0 ? "connecting" : "reconnecting");
        try {
          let sawEvent = false;
          for await (const event of repositories.recordings.streamEvents(recordingId, {
            lastEventId: lastEventIdRef.current,
            signal: controller.signal,
          })) {
            if (controller.signal.aborted) return;
            sawEvent = true;
            reconnectAttempt = 0;
            lastEventIdRef.current = event.id;
            setLastEventAt(Date.now());
            setState("connected");
            void refreshQueries();

            if (isTerminalRecordingStatus(event.data.status)) {
              await refreshQueries();
              setState("ended");
              return;
            }
          }

          if (controller.signal.aborted) return;
          const latest = await repositories.recordings.getRecording(recordingId);
          await refreshQueries();
          if (isTerminalRecordingStatus(latest.status)) {
            setState("ended");
            return;
          }
          if (!sawEvent) setState("fallback");
        } catch (error) {
          if (controller.signal.aborted) return;
          setState("fallback");
          await refreshQueries();
        }

        reconnectAttempt += 1;
        await waitForReconnect(reconnectDelay(reconnectAttempt), controller.signal);
      }
    };

    void run();
    return () => controller.abort();
  }, [backendStatus, queryClient, recordingId]);

  return { state, lastEventAt };
}
