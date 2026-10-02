import { useQuery, type UseQueryResult } from "@tanstack/react-query";
import type { AsyncResourceState } from "@/domain/resource-state";
import { isDemoMode } from "@/lib/app-config";
import { repositories, type RecordingModel } from "@/repositories";

export const domainQueryKeys = {
  channels: ["channels"] as const,
  channel: (id: string) => ["channels", id] as const,
  recordings: ["recordings"] as const,
  recording: (id: string) => ["recordings", id] as const,
  recordingArtifacts: (id: string) => ["recordings", id, "artifacts"] as const,
  activeRecording: ["recordings", "active"] as const,
  creditBalance: ["credits", "balance"] as const,
  creditTransactions: ["credits", "transactions"] as const,
  creditReservations: ["credits", "reservations"] as const,
  pricing: ["pricing"] as const,
  creditPackages: ["billing", "packages"] as const,
  usage: ["usage", "current"] as const,
};

function toResourceState<T>(
  result: UseQueryResult<T, Error>,
  isEmpty: (value: T) => boolean = () => false,
): AsyncResourceState<T> {
  if (result.isPending) return { kind: "loading" };
  if (result.isError) return { kind: "error", error: result.error };
  const data = result.data;
  if (isEmpty(data)) return { kind: "empty", data };
  if (result.isFetching) return { kind: "stale", data };
  return { kind: "success", data };
}

export function useChannelsData() {
  const query = useQuery({
    queryKey: domainQueryKeys.channels,
    queryFn: () => repositories.channels.list(),
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useChannelData(id: string | null | undefined) {
  const query = useQuery({
    queryKey: domainQueryKeys.channel(id ?? "missing"),
    queryFn: () => repositories.channels.getById(id ?? ""),
    enabled: Boolean(id),
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

const terminalRecordingStatuses = new Set(["completed", "failed", "stopped"]);

function needsRecordingPolling(recording: RecordingModel | null | undefined) {
  return Boolean(recording && !terminalRecordingStatuses.has(recording.backendStatus));
}

function needsRecordingsPolling(recordings: RecordingModel[] | undefined) {
  return recordings?.some(needsRecordingPolling) ?? false;
}

export function useRecordingsData() {
  const query = useQuery({
    queryKey: domainQueryKeys.recordings,
    queryFn: () => repositories.recordings.list(),
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingsPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useRecordingData(id: string | null | undefined) {
  const query = useQuery({
    queryKey: domainQueryKeys.recording(id ?? "missing"),
    queryFn: () => repositories.recordings.getById(id ?? ""),
    enabled: Boolean(id),
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useRecordingArtifactsData(
  id: string | null | undefined,
  enabled = true,
) {
  const query = useQuery({
    queryKey: domainQueryKeys.recordingArtifacts(id ?? "missing"),
    queryFn: () => repositories.recordings.listArtifacts(id ?? ""),
    enabled: Boolean(id) && enabled,
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useActiveRecordingData() {
  const query = useQuery({
    queryKey: domainQueryKeys.activeRecording,
    queryFn: () => repositories.recordings.getActive(),
    refetchInterval: (current) =>
      !isDemoMode && needsRecordingPolling(current.state.data) ? 5000 : false,
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useCreditBalanceData(enabled = true) {
  const query = useQuery({
    queryKey: domainQueryKeys.creditBalance,
    queryFn: () => repositories.credits.getBalance(),
    enabled,
  });
  return { query, state: toResourceState(query) };
}

export function useCreditTransactionsData(enabled = true) {
  const query = useQuery({
    queryKey: domainQueryKeys.creditTransactions,
    queryFn: () => repositories.credits.listTransactions({ limit: 20 }),
    enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function useCreditReservationsData(enabled = true) {
  const query = useQuery({
    queryKey: domainQueryKeys.creditReservations,
    queryFn: () => repositories.credits.listReservations({ limit: 20 }),
    enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function usePricingData(enabled = true) {
  const query = useQuery({
    queryKey: domainQueryKeys.pricing,
    queryFn: () => repositories.pricing.get(),
    enabled,
  });
  return { query, state: toResourceState(query) };
}

export function useCreditPackagesData(enabled = true) {
  const query = useQuery({
    queryKey: domainQueryKeys.creditPackages,
    queryFn: () => repositories.billing.listPackages(),
    enabled,
  });
  return { query, state: toResourceState(query, (data) => data.items.length === 0) };
}

export function useUsageData() {
  const query = useQuery({
    queryKey: domainQueryKeys.usage,
    queryFn: () => repositories.usage.getCurrent(),
  });
  return { query, state: toResourceState(query) };
}
