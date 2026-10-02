import { useQuery, type UseQueryResult } from "@tanstack/react-query";
import type { AsyncResourceState } from "@/domain/resource-state";
import { repositories } from "@/repositories";

export const domainQueryKeys = {
  channels: ["channels"] as const,
  channel: (id: string) => ["channels", id] as const,
  recordings: ["recordings"] as const,
  activeRecording: ["recordings", "active"] as const,
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

export function useRecordingsData() {
  const query = useQuery({
    queryKey: domainQueryKeys.recordings,
    queryFn: () => repositories.recordings.list(),
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useActiveRecordingData() {
  const query = useQuery({
    queryKey: domainQueryKeys.activeRecording,
    queryFn: () => repositories.recordings.getActive(),
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useUsageData() {
  const query = useQuery({
    queryKey: domainQueryKeys.usage,
    queryFn: () => repositories.usage.getCurrent(),
  });
  return { query, state: toResourceState(query) };
}
