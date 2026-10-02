import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { RecordingStatusValue } from "@/api/types";
import { repositories } from "@/repositories";

const adminKeys = {
  snapshot: ["admin", "operations", "snapshot"] as const,
  recordings: (status?: string | null) =>
    ["admin", "recordings", status ?? "all"] as const,
  recording: (id: string) => ["admin", "recordings", id] as const,
  audit: ["admin", "audit"] as const,
};

const terminalRecordingStatuses = new Set<RecordingStatusValue>([
  "completed",
  "failed",
  "stopped",
]);

export function useAdminOperationalSnapshotData() {
  return useQuery({
    queryKey: adminKeys.snapshot,
    queryFn: () => repositories.admin.getOperationalSnapshot(),
    refetchInterval: 10_000,
  });
}

export function useAdminRecordingsData(status?: RecordingStatusValue | null) {
  return useQuery({
    queryKey: adminKeys.recordings(status),
    queryFn: () =>
      repositories.admin.listRecordings({
        limit: 100,
        status: status ?? null,
      }),
    refetchInterval: 10_000,
  });
}

export function useAdminRecordingData(id: string | null | undefined) {
  return useQuery({
    queryKey: adminKeys.recording(id ?? "missing"),
    queryFn: () => repositories.admin.getRecording(id ?? ""),
    enabled: Boolean(id),
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      return status && !terminalRecordingStatuses.has(status) ? 5_000 : false;
    },
  });
}

export function useAdminAuditData() {
  return useQuery({
    queryKey: adminKeys.audit,
    queryFn: () => repositories.admin.listAudit({ limit: 100 }),
    refetchInterval: 15_000,
  });
}

function idempotencyKey() {
  if (!globalThis.crypto?.randomUUID) {
    throw new Error("Retry requires UUID support in this browser.");
  }
  return globalThis.crypto.randomUUID();
}

export function useAdminRetryRecordingMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (recordingId: string) =>
      repositories.admin.retryRecording(recordingId, idempotencyKey()),
    onSuccess: async (result) => {
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: ["admin", "recordings"] }),
        queryClient.invalidateQueries({ queryKey: adminKeys.snapshot }),
        queryClient.invalidateQueries({ queryKey: adminKeys.audit }),
        queryClient.invalidateQueries({
          queryKey: adminKeys.recording(result.original_recording_id),
        }),
      ]);
    },
  });
}
