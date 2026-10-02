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
