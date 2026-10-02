import { useMutation, useQueryClient } from "@tanstack/react-query";

import { ApiError } from "@/api/errors";
import { domainQueryKeys } from "@/hooks/use-domain-data";
import { repositories } from "@/repositories";

async function invalidateRecordingQueries(
  queryClient: ReturnType<typeof useQueryClient>,
  recordingId: string,
) {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: domainQueryKeys.recording(recordingId) }),
    queryClient.invalidateQueries({ queryKey: domainQueryKeys.recordings }),
    queryClient.invalidateQueries({ queryKey: domainQueryKeys.activeRecording }),
  ]);
}

export function useStopRecordingMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => repositories.recordings.stop(id),
    onSuccess: async (recording) => {
      await invalidateRecordingQueries(queryClient, recording.id);
    },
  });
}

export function useDeleteRecordingMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      await repositories.recordings.delete(id);
      return id;
    },
    onSuccess: async (id) => {
      queryClient.removeQueries({ queryKey: domainQueryKeys.recording(id) });
      queryClient.removeQueries({ queryKey: domainQueryKeys.recordingArtifacts(id) });
      await Promise.all([
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.recordings }),
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.activeRecording }),
        queryClient.invalidateQueries({ queryKey: domainQueryKeys.channels }),
      ]);
    },
  });
}

const DOWNLOAD_EXPIRY_SAFETY_MS = 5_000;

function downloadUrlIsFresh(expiresAt: string) {
  const expires = Date.parse(expiresAt);
  return Number.isFinite(expires) && expires - Date.now() > DOWNLOAD_EXPIRY_SAFETY_MS;
}

export function useRecordingDownloadMutation() {
  return useMutation({
    mutationFn: async (recordingId: string) => {
      const artifacts = await repositories.recordings.listArtifacts(recordingId);
      const artifact = artifacts.find(
        (item) => item.kind === "video" && item.container === "mp4",
      );
      if (!artifact) {
        throw new Error("The recording artifact is unavailable.");
      }

      let result = await repositories.recordings.createArtifactDownloadUrl(artifact.id);
      if (!downloadUrlIsFresh(result.expires_at)) {
        result = await repositories.recordings.createArtifactDownloadUrl(artifact.id);
      }
      if (!downloadUrlIsFresh(result.expires_at)) {
        throw new Error("The download link expired before it could be used.");
      }
      return { artifact, download: result };
    },
  });
}

export function artifactActionErrorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) {
    if (error instanceof Error && error.message.includes("expired")) {
      return "The download link expired. Try again to request a fresh link.";
    }
    if (error instanceof Error && error.message.includes("unavailable")) {
      return "This recording file is no longer available. It may have expired or been cleaned up.";
    }
    return "The recording file could not be downloaded.";
  }
  if (error.status === 404) {
    return "This recording file is no longer available. It may have expired or been cleaned up.";
  }
  if (error.status === 0) {
    return "Unable to reach SaveStream. Check your connection and try again.";
  }
  if (error.status >= 500 || error.retryable) {
    return "Storage is temporarily unavailable. Please try again.";
  }
  return error.serverMessage || "The recording file could not be downloaded.";
}

export function recordingActionErrorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) return "The recording action could not be completed.";
  if (error.status === 0) return "Unable to reach SaveStream. Check your connection and try again.";
  if (error.code === "INSUFFICIENT_CREDITS") {
    return "There are not enough available credits for this recording.";
  }
  if (error.code === "RECORDING_ALREADY_ACTIVE") {
    return "A recording is already active for this source.";
  }
  if (error.status >= 500 || error.retryable) {
    return "SaveStream is temporarily unavailable. Please try again.";
  }
  return error.serverMessage || "The recording action could not be completed.";
}
