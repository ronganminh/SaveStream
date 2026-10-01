import { useQuery, type UseQueryResult } from "@tanstack/react-query";
import type { AsyncResourceState } from "@/domain/resource-state";
import { getRepositories } from "@/repositories";

export const domainQueryKeys = {
  channels: ["channels"] as const,
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
    queryFn: async () => (await getRepositories()).channels.list(),
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useRecordingsData() {
  const query = useQuery({
    queryKey: domainQueryKeys.recordings,
    queryFn: async () => (await getRepositories()).recordings.list(),
  });
  return { query, state: toResourceState(query, (data) => data.length === 0) };
}

export function useActiveRecordingData() {
  const query = useQuery({
    queryKey: domainQueryKeys.activeRecording,
    queryFn: async () => (await getRepositories()).recordings.getActive(),
  });
  return { query, state: toResourceState(query, (data) => data === null) };
}

export function useUsageData() {
  const query = useQuery({
    queryKey: domainQueryKeys.usage,
    queryFn: async () => (await getRepositories()).usage.getCurrent(),
  });
  return { query, state: toResourceState(query) };
}
