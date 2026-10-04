import { useMutation, useQueryClient } from "@tanstack/react-query";

import { ApiError } from "@/api/errors";
import type { CreateWatchRequest, UpdateWatchRequest } from "@/api/types";
import { domainQueryKeys } from "@/hooks/use-domain-data";
import { repositories } from "@/repositories";

async function invalidateChannels(
  queryClient: ReturnType<typeof useQueryClient>,
  channelId?: string,
) {
  const tasks = [
    queryClient.invalidateQueries({ queryKey: domainQueryKeys.channels }),
  ];
  if (channelId) {
    tasks.push(
      queryClient.invalidateQueries({ queryKey: domainQueryKeys.channel(channelId) }),
    );
  }
  await Promise.all(tasks);
}

export function useCreateChannelMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: CreateWatchRequest) => repositories.channels.create(input),
    onSuccess: async (watch) => {
      await invalidateChannels(queryClient, watch.id);
    },
  });
}

export function useUpdateChannelMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: UpdateWatchRequest }) =>
      repositories.channels.update(id, input),
    onSuccess: async (watch) => {
      await invalidateChannels(queryClient, watch.id);
    },
  });
}

export function usePauseChannelMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => repositories.channels.pause(id),
    onSuccess: async (watch) => {
      await invalidateChannels(queryClient, watch.id);
    },
  });
}

export function useResumeChannelMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => repositories.channels.resume(id),
    onSuccess: async (watch) => {
      await invalidateChannels(queryClient, watch.id);
    },
  });
}

export function useDeleteChannelMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await repositories.channels.delete(id);
      return id;
    },
    onSuccess: async (id) => {
      queryClient.removeQueries({ queryKey: domainQueryKeys.channel(id) });
      await queryClient.invalidateQueries({ queryKey: domainQueryKeys.channels });
    },
  });
}

function detailsRecord(error: ApiError): Record<string, unknown> | null {
  if (!error.details || typeof error.details !== "object" || Array.isArray(error.details)) {
    return null;
  }
  return error.details as Record<string, unknown>;
}

export function existingWatchId(error: unknown): string | null {
  if (!(error instanceof ApiError) || error.status !== 409) return null;
  const value = detailsRecord(error)?.["watch_id"];
  return typeof value === "string" && value.length > 0 ? value : null;
}

export function watchQuotaLimit(error: unknown): number | null {
  if (!(error instanceof ApiError)) return null;
  const details = detailsRecord(error);
  if (error.code === "WATCH_LIMIT_REACHED") {
    return typeof details?.["limit"] === "number" ? details["limit"] : null;
  }
  if (error.code !== "RATE_LIMITED") return null;
  if (details?.["quota"] !== "max_watches_per_user") return null;
  return typeof details["limit"] === "number" ? details["limit"] : null;
}

export function channelActionErrorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) return "The channel action could not be completed.";
  if (error.status === 0) return "Unable to reach SaveStream. Check your connection and try again.";
  if (error.code === "INSUFFICIENT_CREDITS") {
    return "There are not enough available credits to resume automatic recording.";
  }
  if (error.code === "PLAN_REQUIRED") {
    return "Automatic cloud recording requires a one-time hour purchase. Monitoring remains available on Free.";
  }
  if (error.code === "WATCH_LIMIT_REACHED" || error.code === "RATE_LIMITED") {
    return "Your account has reached the monitored-channel limit. Buy hours to unlock the Pro limit.";
  }
  if (error.status >= 500 || error.retryable) {
    return "SaveStream is temporarily unavailable. Please try again.";
  }
  return error.serverMessage || "The channel action could not be completed.";
}
